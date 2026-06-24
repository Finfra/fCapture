fCapture를 Release 빌드하고 로컬(jm4) 및 jma.local 양쪽에 배포한다.

## 절차
1. `cd fCapture && swift build -c release` 로 Release 빌드
2. 빌드 성공 시 `.build/release/fCapture` → `~/.bin/fCapture` 복사 (로컬)
3. 로컬 배포 확인 (`ls -lh ~/.bin/fCapture`)
4. jma.local에 동일 경로로 scp 배포 (`scp fCapture/.build/release/fCapture jma:~/.bin/fCapture`)
5. 결과 보고 (빌드 성공/실패, 파일 크기, 로컬/리모트 경로)
> `bin/fCapture`는 빌드 바이너리를 직접 참조하는 쉘 래퍼 — 복사 불필요
