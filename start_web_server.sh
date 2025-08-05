#!/bin/bash

echo "🚀 리튼 앱 웹 서버 시작 중..."

# 기존 서버 프로세스 종료
pkill -f "python3 -m http.server 8080" 2>/dev/null

# 웹 디렉토리로 이동
cd /mnt/c/work/liten/3.development/liten/frontend/liten_app

# Flutter 웹 빌드
echo "📦 Flutter 웹 빌드 중..."
/mnt/c/work/liten/3.development/liten/flutter/bin/flutter build web --web-renderer html

# 빌드 디렉토리로 이동
cd build/web

# 웹 서버 시작
echo "🌐 웹 서버 시작 중..."
python3 -m http.server 8080 &

# 서버 PID 저장
SERVER_PID=$!
echo $SERVER_PID > /tmp/liten_web_server.pid

echo ""
echo "✅ 리튼 앱이 성공적으로 시작되었습니다!"
echo ""
echo "🌍 다음 주소로 접속하세요:"
echo "   http://localhost:8080"
echo "   http://127.0.0.1:8080"
echo ""
echo "🛑 서버를 중지하려면:"
echo "   kill $SERVER_PID"
echo "   또는 pkill -f 'python3 -m http.server 8080'"
echo ""

# 서버 상태 확인
sleep 2
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "🟢 서버가 정상적으로 실행 중입니다."
else
    echo "🔴 서버 시작에 실패했습니다."
fi