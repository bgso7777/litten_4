#!/bin/bash

echo "=== 리튼 웹 서버 시작 ==="

# 포트 확인 및 종료
echo "기존 프로세스 확인 중..."
if lsof -ti:8080 > /dev/null 2>&1; then
    echo "포트 8080이 사용 중입니다. 기존 프로세스를 종료합니다."
    pkill -f "python.*8080" 2>/dev/null || true
    sleep 2
fi

# build/web 디렉토리 확인
if [ ! -d "build/web" ]; then
    echo "build/web 디렉토리가 없습니다. 먼저 빌드를 실행합니다..."
    ../flutter/bin/flutter build web
    if [ $? -ne 0 ]; then
        echo "빌드에 실패했습니다."
        exit 1
    fi
fi

# Python HTTP 서버 시작 (백그라운드)
echo "웹 서버 시작 중..."
cd build/web

# Python 버전에 따른 서버 실행
if command -v python3 > /dev/null 2>&1; then
    echo "Python3로 서버를 시작합니다..."
    python3 -m http.server 8080 &
elif command -v python > /dev/null 2>&1; then
    echo "Python으로 서버를 시작합니다..."
    python -m http.server 8080 &
else
    echo "Python이 설치되어 있지 않습니다."
    exit 1
fi

# 서버 PID 저장
SERVER_PID=$!
echo $SERVER_PID > ../web_server.pid

# 잠시 대기 후 서버 상태 확인
sleep 3

if kill -0 $SERVER_PID 2>/dev/null; then
    echo ""
    echo "✅ 리튼 웹 서버가 성공적으로 시작되었습니다!"
    echo ""
    echo "📱 브라우저에서 다음 주소로 접속하세요:"
    echo "   http://localhost:8080"
    echo ""
    echo "🔍 새로운 기능:"
    echo "   - 쓰기 탭에서 +텍스트 버튼으로 텍스트 문서 작성"
    echo "   - 쓰기 탭에서 +PDF 버튼으로 PDF 업로드 및 필기"
    echo "   - 파일 목록에서 작성된 문서들 확인"
    echo ""
    echo "⏹️  서버를 종료하려면: ./stop_web_server.sh"
    echo ""
else
    echo "❌ 서버 시작에 실패했습니다."
    exit 1
fi