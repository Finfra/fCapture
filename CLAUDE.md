---
title: fCapture CLAUDE.md
description: Claude Code가 fCapture 프로젝트에서 작업할 때 참고하는 가이드
date: 2026-04-04
---

글로벌 규칙(언어, 스타일, 네이밍 등)은 `~/.claude/CLAUDE.md` 참조.

# 프로젝트 개요

macOS Swift CLI 기반의 스크린 캡처 도구. CoreGraphics를 활용하여 전체 화면, 특정 디스플레이, 윈도우, 영역 캡처를 지원하며, JSON 설정 파일로 다양한 캡처 시나리오를 자동화함.

# 사용자 설정

* **Language**: Korean (한국어) - Thinking Process 포함 모두 한국어
* **Notification**: 작업 완료 시 `say 'Complished'` 실행
* **Issue Completion**: 완료(✅) 처리 시 Commit Hash 필수 기록 **(Protocol: Code Commit → Get Hash → Update Issue.md → Commit Issue.md)**

# 구조

* `fCapture/` - Swift 소스 코드 (SPM 프로젝트)
    - `Package.swift` - SPM 정의 (macOS 13+, executable)
    - `ScreenCapture.swift` - 핵심 캡처 모듈 (CoreGraphics)
    - `ScreenCaptureApp.swift` - CLI 진입점 + 설정/상태 관리
* `data/settings/` - JSON 설정 예제 파일
* `bin/fCapture` - 쉘 래퍼 스크립트 (**수정 금지**)
* `buildAndTest.sh` - 통합 빌드/테스트/배포 스크립트
* `captureTest.sh` - 캡처 테스트 스크립트

# 중요 관련 파일

| 카테고리   | 파일명                                                      | 설명             |
| :--------- | :---------------------------------------------------------- | :--------------- |
| 필수       | [README.md](./README.md)                                    | 기술 아키텍처    |
| 필수       | [Issue.md](./Issue.md)                                      | 이슈 관리        |
| 소스       | [ScreenCapture.swift](./fCapture/ScreenCapture.swift)       | 핵심 캡처 모듈   |
| 소스       | [ScreenCaptureApp.swift](./fCapture/ScreenCaptureApp.swift) | CLI 앱 진입점    |
| 소스       | [Package.swift](./fCapture/Package.swift)                   | SPM 프로젝트     |
| 설정       | `~/.fCapture/defaultSetting.json`                           | 사용자 기본 설정 |
| 예제       | [data/README.md](./data/README.md)                          | JSON 예제 가이드 |

# 개발 환경

* **macOS**: 13.0+ (타겟), 15.5+ (현재 개발 환경)
* **Swift**: 5.9 (Swift Package Manager)
* **프레임워크**: Foundation, CoreGraphics, AppKit
* **권한**: 스크린 녹화 권한 (Screen Recording)

# Quick Start

```bash
# Release 빌드 + 테스트 + ~/.bin 배포
./buildAndTest.sh

# Clean 빌드
./buildAndTest.sh clean

# 수동 빌드
cd fCapture && swift build -c release

# 실행
fCapture                              # 기본 설정 (윈도우 캡처)
fCapture data/settings/01_screen1.json  # JSON 설정 지정
```

# 배포

* **빌드 바이너리**: `fCapture/.build/release/fCapture`
* **글로벌 배포**: `~/.bin/fCapture`
* **상태 파일**: `~/.fCapture/info_stateManager.json`

# Claude Code 커맨드 (`.claude/commands/`)

| 커맨드         | 설명                                                             |
| :------------- | :--------------------------------------------------------------- |
| `build`        | fCapture Release 빌드만 수행 (배포 없음)                         |
| `deploy`       | Release 빌드 후 로컬(jm4) 및 jma.local 양쪽에 배포              |
| `dev`          | fCapture 개발 주기 실행 (dev 스킬 호출)                          |
| `run`          | fCapture 빌드 및 실행 테스트                                     |
| `test`         | fCapture QA 테스트 (설정 파일 전수 실행)                         |
| `verify`       | 배포하지 않고 빌드만 검증                                        |
| `git`          | Git 작업 수행 (status, add, commit, push 또는 일괄 처리)         |
| `issue`        | 이슈 관리 및 자동화 워크플로우 (분석 → 등록/이동 → 해결)        |
| `issue-reg`    | 이슈 등록 (HWM 확인 → ID 발급 → 파일 업데이트)                  |
| `issue-fix`    | 이슈 해결 및 완료 처리 (Fix → Verify → Doc → Close)             |
| `issue-closer` | 이슈 종결 및 문서 업데이트 (Hash 확보 → 완료 이동 → Doc 커밋)   |
| `refactor`     | 리팩토링 및 구조 개선 워크플로우                                 |
| `toc`          | 마크다운 파일의 목차(TOC) 자동 생성/업데이트                     |
| `rule-mgr`     | 프로젝트 규칙(.claude/rules/) 관리 워크플로우                    |
| `skill-mgr`    | 스킬 관리 및 개선 (생성/수정 → 표준화)                           |
| `workflow-mgr` | 워크플로우 관리 및 개선 (분석 → 생성/수정 → 표준화)              |

# Claude Code 스킬 (`.claude/skills/`)

| 스킬               | 설명                                                                         |
| :----------------- | :--------------------------------------------------------------------------- |
| `dev`              | fCapture 개발 주기 (dev-m 기반, Swift CLI 도구 특화)                         |
| `issue`            | Issue.md 수명 주기 관리 (상태 분석 → 자동 결정 → 등록/해결/종결)            |
| `issue-manager`    | 이슈 등록/종결 절차 (issue-m → issue-g 기반)                                 |
| `issue-hwm`        | Issue.md HWM(High Water Mark) 확인 및 Self-Healing 동기화                    |
| `qa`               | 설정 파일 기반 QA 테스트 (data/settings/ JSON 자동 감지 → 바이너리 실행)     |
| `save-point-update`| 커밋 후 커밋 해시를 Issue.md의 Save Point에 기록                             |
| `toc`              | 마크다운 파일의 목차(TOC) 자동 생성/업데이트                                 |

# Claude Code 에이전트 (`.claude/agents/`)

| 에이전트       | 설명                                 |
| :------------- | :----------------------------------- |
| `build`        | fCapture 빌드 전용 에이전트          |
| `build-doctor` | fCapture 빌드 에러 진단 전용         |
| `deployment`   | fCapture 배포 전용 에이전트          |
| `git`          | fCapture Git 작업 전용 에이전트      |
| `qa`           | fCapture QA 테스트 전용 에이전트     |
| `refactor`     | fCapture 리팩토링 전용 에이전트      |
| `rule-manager` | fCapture 규칙 관리 전용 에이전트     |
| `verify`       | fCapture 빌드 검증 전용 에이전트     |

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
