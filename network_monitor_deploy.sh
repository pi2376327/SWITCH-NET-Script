#!/bin/sh
# ====================================================================
# SDWAN CPE 流量监控系统 一键全自动纯净/覆盖部署脚本 (Bug修复版)
# 适用环境：OpenWrt 21.02 / 22.03 / 23.05 + (完美兼容 ARM / x86 架构)
# 修复日志：
#   1. 彻底将 RRD 数据库由 COUNTER 变更为 GAUGE 模式，由后台直接计算精确的 Mbps 存入。
#   2. 根治了长周期（2天/7天/1年）因接口重启或累加导致的假溢出、天价尖峰撑爆Y轴的 Bug。
#   3. 精简前后端换算逻辑，避免多重乘除造成的数据量级失真。
# 视觉保留：X/Y轴线与纵坐标横格线全面加粗并切换为浅灰色，高对比度。
# ====================================================================

set -e

echo "========= [1/6] 正在执行旧版本残余清理及数据库重置 ========="

# 1. 安全从计划任务中剔除旧的采集器
if crontab -l 2>/dev/null | grep -q "traffic_collector.sh"; then
    echo "发现旧的计划任务标识，正在解除绑定..."
    crontab -l 2>/dev/null | grep -v "traffic_collector.sh" | crontab - || true
fi

# 2. 强制终止当前可能正在后台运行的旧版采集实例
killall traffic_collector.sh 2>/dev/null || true

# 3. 彻底清空历史安装路径及旧的前端残留文件（必须删除旧rrd以应用新GAUGE结构）
echo "正在强力抹除旧系统文件与 RRD 历史数据库..."
rm -rf /usr/share/traffic_rrd
rm -f /usr/bin/traffic_collector.sh
rm -f /www/cgi-bin/get_history_speed
rm -f /www/cgi-bin/get_net_speed
rm -rf /www/speed

echo "========= [2/6] 正在初始化全新环境及依赖环境校验 ========="
if ! command -v rrdtool >/dev/null 2>&1; then
    echo "未检测到 rrdtool，正在尝试从 opkg 软件源进行自动拉取安装..."
    opkg update
    opkg install rrdtool awk
else
    echo "RRDtool 环境检查正常，跳过安装。"
fi

# 4. 重新建立纯净的系统工作目录
mkdir -p /usr/share/traffic_rrd
mkdir -p /usr/bin
mkdir -p /www/cgi-bin
mkdir -p /www/speed

# ================= 架构检测核心变量定义 =================
ARCH_TYPE=$(uname -m)
GLOBAL_WAN="eth0"

case "$ARCH_TYPE" in
    x86_64|i386|i686)
        GLOBAL_WAN="eth0"
        ;;
    aarch64*|arm*|mips*)
        GLOBAL_WAN="eth1"
        ;;
    *)
        GLOBAL_WAN="eth0"
        ;;
esac
echo "系统底层架构为: $ARCH_TYPE，已选定专用 WAN 接口: $GLOBAL_WAN"
# =======================================================

echo "========= [3/6] 正在生成后台定时流量统计采集器 (traffic_collector.sh) ========="
cat << 'OUTER_EOF' > /usr/bin/traffic_collector.sh
#!/bin/sh
DB_DIR="/usr/share/traffic_rrd"
CACHE_DIR="/tmp/traffic_cache"
mkdir -p "$DB_DIR"
mkdir -p "$CACHE_DIR"

INTERFACES="TARGET_WAN br-lan"

# 变更核心：采用 GAUGE 存储直接换算好的 Mbps 速率
init_rrd() {
    local iface=$1
    if [ ! -f "$DB_DIR/$iface.rrd" ]; then
        rrdtool create "$DB_DIR/$iface.rrd" --step 60 \
            DS:rx:GAUGE:120:0:U \
            DS:tx:GAUGE:120:0:U \
            RRA:AVERAGE:0.5:1:4320 \
            RRA:AVERAGE:0.5:5:8640 \
            RRA:AVERAGE:0.5:30:5760 \
            RRA:AVERAGE:0.5:120:4400
    fi
}

get_bytes() {
    local iface=$1
    awk -v ifn="$iface" '$1 ~ "^"ifn":" {print $2, $10}' /proc/net/dev
}

# 计算当前的 Mbps 速率
calc_speed() {
    local iface=$1
    local current_rx=$2
    local current_tx=$3
    local cache_file="$CACHE_DIR/$iface.cache"
    
    if [ -f "$cache_file" ]; then
        read -r last_time last_rx last_tx < "$cache_file"
        local now=$(date +%s)
        local time_delta=$((now - last_time))
        if [ $time_delta -gt 0 ] && [ $current_rx -ge $last_rx ] && [ $current_tx -ge $last_tx ]; then
            # 计算 Mbps: (Bytes_delta * 8) / time_delta / 1024 / 1024
            # 考虑 shell 不支持浮点数，先放大 100 倍计算再转为浮点字符串
            local rx_speed_scaled=$(( (current_rx - last_rx) * 8 * 100 / time_delta / 1024 / 1024 ))
            local tx_speed_scaled=$(( (current_tx - last_tx) * 8 * 100 / time_delta / 1024 / 1024 ))
            
            rx_speed=$(awk -v s=$rx_speed_scaled 'BEGIN {printf "%.2f", s/100}')
            tx_speed=$(awk -v s=$tx_speed_scaled 'BEGIN {printf "%.2f", s/100}')
        else
            rx_speed="0.00"
            tx_speed="0.00"
        fi
    else
        rx_speed="0.00"
        tx_speed="0.00"
    fi
    echo "$(date +%s) $current_rx $current_tx" > "$cache_file"
}

# 初始化物理和虚拟总线数据库
for i in $INTERFACES TUN_TOTAL; do init_rrd "$i"; done
for tun in $(awk -F: 'NR>2 {print $1}' /proc/net/dev | tr -d ' ' | grep '^tun'); do 
    init_rrd "$tun"; 
done

# 采集标准网口
for iface in $INTERFACES; do
    stats=$(get_bytes "$iface")
    if [ -n "$stats" ]; then
        rx=$(echo "$stats" | awk '{print $1}')
        tx=$(echo "$stats" | awk '{print $2}')
        calc_speed "$iface" "$rx" "$tx"
        rrdtool update "$DB_DIR/$iface.rrd" N:"$rx_speed":"$tx_speed"
    fi
done

# 采集所有的 TUN 接口并精密聚合
total_tun_rx=0
total_tun_tx=0
for tun in $(awk -F: 'NR>2 {print $1}' /proc/net/dev | tr -d ' ' | grep '^tun'); do
    stats=$(get_bytes "$tun")
    if [ -n "$stats" ]; then
        rx=$(echo "$stats" | awk '{print $1}')
        tx=$(echo "$stats" | awk '{print $2}')
        [ -z "$rx" ] && rx=0
        [ -z "$tx" ] && tx=0
        total_tun_rx=$((total_tun_rx + rx))
        total_tun_tx=$((total_tun_tx + tx))
        
        calc_speed "$tun" "$rx" "$tx"
        rrdtool update "$DB_DIR/$tun.rrd" N:"$rx_speed":"$tx_speed" 2>/dev/null || true
    fi
done

# 统一更新 SDWAN 专线总流量总成
calc_speed "TUN_TOTAL" "$total_tun_rx" "$total_tun_tx"
rrdtool update "$DB_DIR/TUN_TOTAL.rrd" N:"$rx_speed":"$tx_speed"
OUTER_EOF

# 精准替换采集器中的 WAN 接口标识
sed -i "s/TARGET_WAN/$GLOBAL_WAN/g" /usr/bin/traffic_collector.sh
chmod +x /usr/bin/traffic_collector.sh

echo "========= [4/6] 正在生成后端数据路由 CGI 接口服务 ========="
cat << 'OUTER_EOF' > /www/cgi-bin/get_history_speed
#!/bin/sh
echo "Content-type: application/json"
echo ""
TIME_RANGE="-1h"
RESOLUTION="60"
if [ -n "$QUERY_STRING" ]; then
    TIME_RANGE="-$(echo "$QUERY_STRING" | cut -d'&' -f1)"
    RESOLUTION="$(echo "$QUERY_STRING" | cut -d'&' -f2)"
fi
DB_DIR="/usr/share/traffic_rrd"
echo "{"
first=1
for f in "$DB_DIR"/*.rrd; do
    [ -e "$f" ] || continue
    iface=$(basename "$f" .rrd)
    if [ $first -ne 1 ]; then echo ","; fi
    first=0
    echo "\"$iface\": ["
    # 核心调整：因为 RRDtool 里已经是准确的 Mbps 浮点数，直接输出，过滤 nan 即可
    rrdtool fetch "$f" AVERAGE -s "$TIME_RANGE" -e "now" -r "$RESOLUTION" | awk '
        NR > 2 {
            if ($1 != "") {
                sub(/:/, "", $1);
                val_rx = ($2 ~ /nan/) ? 0 : $2;
                val_tx = ($3 ~ /nan/) ? 0 : $3;
                printf "{\x22time\x22: \x22%s\x22, \x22rx\x22: %.2f, \x22tx\x22: %.2f},\n", $1, val_rx, val_tx
            }
        }
    ' | sed '$s/,$//'
    echo "]"
done
echo "}"
OUTER_EOF

cat << 'OUTER_EOF' > /www/cgi-bin/get_net_speed
#!/bin/sh
echo "Content-type: application/json"
echo ""
echo "{"
awk 'NR > 2 {
    sub(/:/, "", $1);
    printf "\"%s\": {\"rx\": %s, \"tx\": %s},\n", $1, $2, $10
}' /proc/net/dev | sed '$s/,$//'
echo "}"
OUTER_EOF

chmod +x /www/cgi-bin/get_history_speed
chmod +x /www/cgi-bin/get_net_speed

echo "========= [5/6] 正在生成前端高阶主页面 (index.html) ========="
cat << 'OUTER_EOF' > /www/speed/index.html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>SDWAN CPE 流量监控系统</title>
    <script src="https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"></script>
    <style>
        :root {
            --bg-main: #0b111e; --bg-card: #121b2e; --border-color: #1e2d4a;
            --text-main: #f1f5f9; --text-muted: #64748b; --theme-blue: #38bdf8;
            --theme-green: #00e676; --theme-red: #ff3d00;
        }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background-color: var(--bg-main); color: var(--text-main); padding: 30px; margin: 0; -webkit-font-smoothing: antialiased; }
        .container { max-width: 1400px; margin: 0 auto; }
        .login-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: var(--bg-main); z-index: 9999; display: flex; justify-content: center; align-items: center; }
        .login-box { background: var(--bg-card); border: 1px solid var(--border-color); padding: 40px; border-radius: 12px; width: 320px; text-align: center; box-shadow: 0 20px 50px rgba(0,0,0,0.5); }
        .login-box h2 { margin-top: 0; font-size: 1.3rem; color: var(--theme-blue); margin-bottom: 25px; font-weight: 600; }
        .login-box input { width: 100%; padding: 11px; margin-bottom: 15px; border-radius: 6px; box-sizing: border-box; border: 1px solid var(--border-color); background: #16223b; color: #fff; outline: none; }
        .login-box button { width: 100%; background: var(--theme-blue); color: #0b111e; font-weight: bold; border: none; padding: 11px; border-radius: 6px; cursor: pointer; transition: 0.2s; }
        .login-box button:hover { background: #0ea5e9; }
        .header-panel { text-align: center; margin-bottom: 25px; }
        h1 { font-size: 2.2rem; font-weight: 700; letter-spacing: 1px; background: linear-gradient(to right, #38bdf8, #00e676); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin: 0; }
        .navigation-tabs { display: flex; justify-content: center; gap: 8px; margin-bottom: 25px; }
        .nav-tab { background: #16223b; color: var(--text-muted); border: 1px solid var(--border-color); padding: 10px 24px; font-size: 0.95rem; font-weight: 600; border-radius: 6px; cursor: pointer; transition: 0.2s; }
        .nav-tab:hover { color: var(--text-main); }
        .nav-tab.active { background: #1e2d4a; color: var(--theme-green); border-color: var(--theme-green); box-shadow: 0 4px 15px rgba(0,230,118,0.15); }
        .btn-wrapper { text-align: center; width: 100%; margin-bottom: 30px; display: none; }
        .control-row { display: inline-flex; gap: 4px; background: var(--bg-card); border: 1px solid var(--border-color); padding: 5px; border-radius: 8px; box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3); flex-wrap: wrap; justify-content: center; }
        .control-row button { background: transparent; border: none; color: var(--text-muted); padding: 8px 14px; font-size: 0.85rem; font-weight: 500; border-radius: 5px; cursor: pointer; }
        .control-row button:hover { color: var(--text-main); }
        .control-row button.active { background: #1e2d4a; color: var(--theme-blue); font-weight: 600; }
        .chart-grid { display: grid; grid-template-columns: 1fr; gap: 25px; }
        .chart-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 12px; padding: 24px; height: 380px; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2); }
        #realtime-grid { display: grid; } #history-grid { display: none; }
    </style>
</head>
<body>
    <div class="login-overlay" id="loginWall">
        <div class="login-box">
            <h2>SDWAN CPE 网络流量监控</h2>
            <input type="text" id="username" placeholder="管理员账号" onkeydown="handleKeyDown(event)">
            <input type="password" id="password" placeholder="访问密码" onkeydown="handleKeyDown(event)">
            <button onclick="checkLogin()">安全登录</button>
            <p id="loginErr" style="color:var(--theme-red); font-size:0.85rem; margin-top:15px; display:none; font-weight:500;">凭据错误，拒绝访问</p>
        </div>
    </div>
    <div class="container">
        <div class="header-panel"><h1>SDWAN CPE流量监控</h1></div>
        <div class="navigation-tabs">
            <div class="nav-tab active" id="tab-realtime" onclick="switchMode('realtime')">实时网络监控</div>
            <div class="nav-tab" id="tab-history" onclick="switchMode('history')">历史网络查看</div>
        </div>
        <div class="btn-wrapper" id="history-controls">
            <div class="control-row">
                <button onclick="changeHistoryRange('30m', 60, this)">30分钟</button>
                <button class="active" onclick="changeHistoryRange('1h', 60, this)">1小时</button>
                <button onclick="changeHistoryRange('6h', 60, this)">6小时</button>
                <button onclick="changeHistoryRange('12h', 60, this)">12小时</button>
                <button onclick="changeHistoryRange('24h', 60, this)">24小时</button>
                <button onclick="changeHistoryRange('2d', 60, this)">2天</button>
                <button onclick="changeHistoryRange('7d', 300, this)">7天</button>
                <button onclick="changeHistoryRange('15d', 300, this)">15天</button>
                <button onclick="changeHistoryRange('30d', 300, this)">1个月</button>
                <button onclick="changeHistoryRange('90d', 1800, this)">3个月</button>
                <button onclick="changeHistoryRange('180d', 1800, this)">6个月</button>
                <button onclick="changeHistoryRange('365d', 7200, this)">1年</button>
            </div>
        </div>
        <div class="chart-grid" id="realtime-grid"></div>
        <div class="chart-grid" id="history-grid"></div>
    </div>
    <script>
        function handleKeyDown(event) { if (event.key === "Enter" || event.keyCode === 13) { checkLogin(); } }
        function checkLogin() {
            const u = document.getElementById('username').value; const p = document.getElementById('password').value;
            if(u === "admin" && p === "admin888") { sessionStorage.setItem("cpe_auth", "passed"); document.getElementById('loginWall').style.display = 'none'; initSystem(); } else { document.getElementById('loginErr').style.display = 'block'; }
        }
        if(sessionStorage.getItem("cpe_auth") === "passed") { document.getElementById('loginWall').style.display = 'none'; window.onload = initSystem; }
        let appMode = 'realtime'; let currentRange = '1h'; let currentResolution = 60; let realtimeCharts = {}; let historyCharts = {}; let realtimeTimer = null; let historyTimer = null; let previousStats = {}; let previousTime = Date.now();
        
        const nameMapping = { 'TUN_TOTAL': 'SDWAN专线流量图', 'TARGET_WAN': 'WAN口流量图', 'br-lan': 'LAN口流量图' };
        const orderedInterfaces = ['TUN_TOTAL', 'TARGET_WAN', 'br-lan'];

        function initSystem() { switchMode('realtime'); realtimeTimer = setInterval(loadRealtimeData, 2000); historyTimer = setInterval(loadHistoryData, 30000); }
        function switchMode(mode) {
            appMode = mode; document.getElementById('tab-realtime').classList.remove('active'); document.getElementById('tab-history').classList.remove('active');
            if(mode === 'realtime') {
                document.getElementById('tab-realtime').classList.add('active'); document.getElementById('history-controls').style.display = 'none'; document.getElementById('history-grid').style.display = 'none'; document.getElementById('realtime-grid').style.display = 'grid';
                for (let k in realtimeCharts) { realtimeCharts[k].resize(); } loadRealtimeData();
            } else {
                document.getElementById('tab-history').classList.add('active'); document.getElementById('history-controls').style.display = 'block'; document.getElementById('realtime-grid').style.display = 'none'; document.getElementById('history-grid').style.display = 'grid';
                for (let k in historyCharts) { historyCharts[k].resize(); } loadHistoryData();
            }
        }
        async function loadRealtimeData() {
            try {
                const res = await fetch('/cgi-bin/get_net_speed'); const currentStats = await res.json(); const now = Date.now(); const timeDelta = (now - previousTime) / 1000 || 1; previousTime = now; const gridContainer = document.getElementById('realtime-grid');
                let activeIfaces = []; orderedInterfaces.forEach(i => { if(currentStats[i]) activeIfaces.push(i); }); if(!activeIfaces.includes('TUN_TOTAL')) activeIfaces.unshift('TUN_TOTAL');
                for (const key in currentStats) { if (!activeIfaces.includes(key) && key.startsWith('tun')) { activeIfaces.push(key); } }
                activeIfaces.forEach(iface => {
                    let rxMbps = 0, txMbps = 0;
                    if (iface === 'TUN_TOTAL') {
                        let tunRxBps = 0, tunTxBps = 0; for (const key in currentStats) { if (key.startsWith('tun')) { const curTun = currentStats[key]; const prvTun = previousStats[key] || curTun; tunRxBps += (curTun.rx - prvTun.rx); tunTxBps += (curTun.tx - prvTun.tx); } }
                        rxMbps = parseFloat((tunRxBps * 8 / timeDelta / 1024 / 1024).toFixed(2)); txMbps = parseFloat((tunTxBps * 8 / timeDelta / 1024 / 1024).toFixed(2));
                    } else {
                        const current = currentStats[iface] || {rx:0, tx:0}; const prev = previousStats[iface] || current;
                        rxMbps = parseFloat((((current.rx - prev.rx) * 8 / timeDelta) / 1024 / 1024).toFixed(2)); txMbps = parseFloat((((current.tx - prev.tx) * 8 / timeDelta) / 1024 / 1024).toFixed(2));
                    }
                    if (rxMbps < 0 || isNaN(rxMbps)) rxMbps = 0; if (txMbps < 0 || isNaN(txMbps)) txMbps = 0;
                    if (!realtimeCharts[iface]) {
                        const card = document.createElement('div'); card.className = 'chart-card'; card.id = `rt-chart-${iface}`; gridContainer.appendChild(card); realtimeCharts[iface] = echarts.init(card, 'dark');
                        realtimeCharts[iface].timeline = new Array(30).fill(''); realtimeCharts[iface].rxTrack = new Array(30).fill(0); realtimeCharts[iface].txTrack = new Array(30).fill(0);
                    }
                    const c = realtimeCharts[iface]; const timeStr = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'});
                    c.timeline.shift(); c.timeline.push(timeStr); c.rxTrack.shift(); c.rxTrack.push(rxMbps); c.txTrack.shift(); c.txTrack.push(txMbps);
                    renderEChart(realtimeCharts[iface], iface, c.timeline, c.rxTrack, c.txTrack, true);
                });
                previousStats = currentStats;
            } catch (e) { console.error(e); }
        }
        async function loadHistoryData() {
            try {
                const response = await fetch(`/cgi-bin/get_history_speed?${currentRange}&${currentResolution}`); const data = await response.json(); const gridContainer = document.getElementById('history-grid');
                let activeIfaces = []; orderedInterfaces.forEach(i => { if(data[i]) activeIfaces.push(i); }); if(!activeIfaces.includes('TUN_TOTAL')) activeIfaces.unshift('TUN_TOTAL');
                for (const key in data) { if (!activeIfaces.includes(key) && key.startsWith('tun')) { activeIfaces.push(key); } }
                activeIfaces.forEach(iface => {
                    const records = data[iface] || [];
                    const labels = records.map(r => { let d = new Date(parseInt(r.time.replace(':', '')) * 1000); return currentResolution >= 300 ? `${d.getMonth()+1}-${d.getDate()} ${d.getHours()}:${(d.getMinutes()<10?'0':'')+d.getMinutes()}` : d.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}); });
                    
                    // 核心修正：因为后台写入已是标准 Mbps 速率，这里直接提取，不需要再做除法
                    const rxData = records.map(r => r.rx); const txData = records.map(r => r.tx);
                    
                    if (!historyCharts[iface]) { const card = document.createElement('div'); card.className = 'chart-card'; card.id = `hi-chart-${iface}`; gridContainer.appendChild(card); historyCharts[iface] = echarts.init(card, 'dark'); }
                    renderEChart(historyCharts[iface], iface, labels, rxData, txData, false);
                });
            } catch (e) { console.error(e); }
        }
        function changeHistoryRange(range, resolution, btn) { currentRange = range; currentResolution = resolution; document.querySelectorAll('.control-row button').forEach(b => b.classList.remove('active')); btn.classList.add('active'); document.getElementById('history-grid').innerHTML = ''; historyCharts = {}; loadHistoryData(); }
        function renderEChart(chartInstance, iface, labels, rx, tx, isSmooth) {
            let labelName = nameMapping[iface] || `TUN口流量图 (${iface})`;
            chartInstance.setOption({
                backgroundColor: 'transparent', title: { text: labelName, left: 'center', top: 5, textStyle: { color: '#f1f5f9', fontSize: 16, fontWeight: 'bold' } },
                tooltip: { trigger: 'axis', backgroundColor: 'rgba(18, 27, 46, 0.95)', borderColor: '#1e2d4a', textStyle: { color: '#f1f5f9' }, boxShadow: '0 8px 32px rgba(0,0,0,0.3)' },
                legend: { data: ['下载 (RX)', '上行 (TX)'], bottom: 5, textStyle: { color: '#64748b', fontWeight: 500 } },
                grid: { top: 70, bottom: 65, left: 65, right: 30 },
                xAxis: { 
                    type: 'category', 
                    boundaryGap: false, 
                    data: labels, 
                    axisLine: { lineStyle: { color: '#94a3b8', width: 2 } }, 
                    axisLabel: { color: '#64748b' } 
                },
                yAxis: { 
                    type: 'value', 
                    name: 'Mbps', 
                    nameTextStyle: { color: '#64748b' }, 
                    splitLine: { 
                        show: true,
                        lineStyle: { color: 'rgba(148, 163, 184, 0.35)', type: 'solid', width: 1.5 } 
                    }, 
                    axisLine: { show: true, lineStyle: { color: '#94a3b8', width: 2 } }, 
                    axisLabel: { color: '#64748b' }, 
                    minInterval: 0.5 
                },
                series: [
                    { name: '下载 (RX)', type: 'line', smooth: isSmooth, showSymbol: false, itemStyle: { color: '#00e676' }, lineStyle: { width: 2 }, areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: 'rgba(0, 230, 118, 0.15)' }, { offset: 1, color: 'rgba(0, 230, 118, 0.0)' }]) }, data: rx },
                    { name: '上行 (TX)', type: 'line', smooth: isSmooth, showSymbol: false, itemStyle: { color: '#ff3d00' }, lineStyle: { width: 2 }, areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: 'rgba(255, 61, 0, 0.1)' }, { offset: 1, color: 'rgba(255, 61, 0, 0.0)' }]) }, data: tx }
                ]
            });
        }
        window.addEventListener('resize', () => { for (let k in realtimeCharts) realtimeCharts[k].resize(); for (let k in historyCharts) historyCharts[k].resize(); });
    </script>
</body>
</html>
OUTER_EOF

# 精准替换网页中的 WAN 接口动态映射
sed -i "s/TARGET_WAN/$GLOBAL_WAN/g" /www/speed/index.html

echo "========= [6/6] 正在向 OpenWrt 重新注册内核级高频计划任务模块 ========="
# 重新将纯净的采集指令挂载入宿主机 Crontab
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/traffic_collector.sh") | crontab -

# 强制重启系统的 cron 计划任务引擎，确保立刻生效
/etc/init.d/cron restart

# 运行采集器
sh /usr/bin/traffic_collector.sh

echo "===================================================================="
echo " 恭喜！专线监控系统已部署完成！"
echo "--------------------------------------------------------------------"
echo " 访问地址 : http://[你的路由器IP]/speed/"
echo " 默认账号 : admin"
echo " 默认密码 : admin888"
echo "===================================================================="
