# 환경 변수 확인 (없으면 기본값 설정)
if (-not $envGEMINI_API_KEY) {
    Write-Error GEMINI_API_KEY 환경변수가 비어 있습니다! 키를 먼저 설정해 주세요.
    exit 1
}
if (-not $envGEMINI_MODEL) { $envGEMINI_MODEL = gemini-2.0-flash }

# 기존 실패 로그가 있다면 초기화
if (Test-Path gemini_failures.jsonl) { Remove-Item gemini_failures.jsonl }

Write-Host ============================================== -ForegroundColor Cyan
Write-Host 🤖 MJC 공지 AI 요약 통합 백필 자동화 스타트 -ForegroundColor Cyan
Write-Host 🎯 사용 모델 $envGEMINI_MODEL -ForegroundColor Cyan
Write-Host ============================================== -ForegroundColor Cyan

# [1회차] 전체 게시판 기본 백필 시작
Write-Host `n[🚀 1회차] 전체 게시글 크롤링 및 최초 요약 시작... -ForegroundColor Green
python backfill_notice_body.py --use-gemini --force --throttle-ms 12000 --failure-log gemini_failures.jsonl

# 재시도 루프 설정 (최대 3번까지 재시도)
$maxRetries = 3
for ($round = 1; $round -le $maxRetries; $round++) {
    
    # 실패 로그 파일이 존재하고, 크기가 0보다 큰지 확인
    if (Test-Path gemini_failures.jsonl) {
        $failCount = (Get-Content gemini_failures.jsonl  Measure-Object).Count
        
        if ($failCount -gt 0) {
            $nextDelay = 12000 + ($round  3000) # 라운드가 진행될수록 대기시간을 늘림 (15초 - 18초 - 21초)
            Write-Host `n[⚠️ 2차 경고] 실패 문서가 $failCount 건 검출되었습니다. -ForegroundColor Yellow
            Write-Host 🔄 [재시도 $round$maxRetries] 10초 대기 후 대기시간 ${nextDelay}ms로 상향하여 재시도합니다... -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            
            # 기존 실패 로그를 백업(재시도 입력용)으로 변경
            Move-Item gemini_failures.jsonl gemini_failures_retry.jsonl -Force
            
            # 실패한 건들만 골라서 다시 백필 수행 (새로운 실패는 다시 gemini_failures.jsonl에 누적)
            python backfill_notice_body.py --retry-failure-log gemini_failures_retry.jsonl --use-gemini --throttle-ms $nextDelay --failure-log gemini_failures.jsonl
            
            # 사용 끝난 임시 파일 삭제
            Remove-Item gemini_failures_retry.jsonl -ErrorAction SilentlyContinue
        } else {
            Write-Host `n🎉 [성공] 모든 문서의 AI 요약이 완벽하게 완료되었습니다! -ForegroundColor Green
            break
        }
    } else {
        Write-Host `n🎉 [성공] 실패한 문서가 단 1건도 없습니다! -ForegroundColor Green
        break
    }
}

Write-Host `n============================================== -ForegroundColor Cyan
Write-Host 🏁 최종 백필 프로세스가 종료되었습니다. -ForegroundColor Cyan
if (Test-Path gemini_failures.jsonl) {
    $finalFail = (Get-Content gemini_failures.jsonl  Measure-Object).Count
    if ($finalFail -gt 0) {
        Write-Host ❌ 최종 실패 문서 $finalFail 건 (이 문서들은 휴리스틱 요약으로 안전하게 처리됨) -ForegroundColor Red
    }
}
Write-Host ============================================== -ForegroundColor Cyan