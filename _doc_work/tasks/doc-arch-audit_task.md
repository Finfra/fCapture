---
name: doc-arch-audit_task
description: _doc_arch ↔ 소스코드 정합성 감사 실행 태스크 — 문서 3종 대조·교정·재검증
date: 2026-07-20
issue: Issue23
plan: _doc_work/plan/doc-arch-audit_plan.md
---

# 진행 규약

| 마커    | 의미        | 비고                                        |
| :------ | :---------- | :------------------------------------------ |
| `- [ ]` | 미착수      |                                             |
| `- [~]` | 진행중      |                                             |
| `- [v]` | 완료        | 완료 근거(커밋 해시·파일 경로) 1줄 병기     |
| `- [x]` | 취소·폐기   | 범위에서 빠진 항목. 삭제하지 말고 이력 보존 |

# T1. 감사 (대조)

- [v] `_doc_arch/` 대상 문서 목록 확정 (`z_done/`·`img/` 제외) — 3종 확정: brew-deploy-design·yaml-companion-config·Glossary
- [v] 축(1) 참조 경로 실존 검증 — 전 경로 실존 확인, 미존재 0건
- [v] 축(2) 심볼·라인 번호 대조 — 함수 15종 실존, 인용 라인 5곳 전부 일치
- [v] 축(3) 동작 서술 대조 — 불일치 3건 확정 (Y2·Y3·G2)
- [v] 축(4) 폐기 설계 잔존 확인 — stale 4건 확정 (B1·B2·B3·B4)

# T2. 교정 (Edit)

- [v] B1 `brew-deploy-design.md` 선결 조건 TODO 해소 반영 (origin·VERSION 실존) — "# 선결 조건 (충족 완료)" 로 개제
- [v] B2 개요의 "외부 설치 경로 없음" 전제 갱신 — 현재 상태(brew 설치 가능) 명시
- [v] B3 `Formula 설계 (source-build)` 헤딩 → 실채택(pre-built binary) 반영
- [v] B3-1 비교표 `A. source-build (채택)` 잔존 발견·교정 — 재검증 grep 에서 적발 (L50 "채택: B" 와 모순)
- [v] B4 sha256 placeholder → 실파일 [`Formula/fcapture.rb`](../../Formula/fcapture.rb) 참조로 교정 (값 복제 금지 원칙 명시)
- [v] B5 `Bundle.main` 인용을 라인 번호 → 심볼명 기준으로 전환 (stale 재발 저감)
- [v] Y2 `findCompanionYAML` 탐색 순서를 실제 루프 구조대로 재기술 (확장자가 바깥 루프) + 진입 가드 2건 보강
- [v] Y3 `t4.default.yml` 자동 연결 주장 정정 + 🔧 [FIXME] 코드 결함 명시
- [v] G2 alias 표를 CLI 경로 / JSON decoder 경로로 분리 기술 (`region` = CLI 전용 alias)
- [v] G3 버전 하드코딩 → VERSION 파일 참조 표현으로 치환
- [v] 부수 발견(코드 결함 4종) 을 문서에 🔧 [FIXME] 로 보존 — companion `.default.yml` 누락·`Usage.txt` `-r,--region` 오기·dead branch·`printHelp` flash 기본값 오기

# T3. 재검증

- [v] 교정 후 전 참조 경로 재-grep → 실존 확인 (12종 전부 OK, 미존재 0건)
- [v] 폐기 표현 잔존 grep — `미충족`·`<release tarball sha256>` 0건. `source-build` 잔존 5건은 전부 이력 서술(의도적 보존)이며, 그중 1건(비교표 "(채택)")은 실제 stale 로 판명되어 교정
- [v] 인용 심볼 13종 전수 재확인 — 전부 실존. `static let appVersion`·companion 확장자 배열 리터럴 일치 확인

# T4. 종결

- [ ] Issue.md Issue23 등록 (HWM 22 → 23)
- [ ] 커밋 (문서 교정 + plan/task)
- [ ] Issue.md ✅ 완료 이동 + commit hash 기록
