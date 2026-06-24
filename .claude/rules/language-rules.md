---
title: 언어 및 커뮤니케이션 규칙
description: fCapture 프로젝트 한국어 우선 정책 — 대화, 태스크, 문서, 커밋 메시지 언어 기준
date: 2026-03-27
---

# 1. 기본 원칙
* **Primary Language**: **Korean (한국어)**
* 시스템의 모든 출력, 로그, 사용자 알림, 대화, 문서, 주석, 워크플로우 상태 메시지 등은 반드시 **한국어**로 작성합니다.
* **Exception (Technical Terms)**: 기술 용어(Function Name, Class Name, Variable, Library, Framework, Error Code 등)는 명확성을 위해 **English (영어)** 원문을 유지합니다.

# 2. 적용 범위 및 예시

## 2.1 대화 및 생각 (Thinking Process)
* **Bad**: "I will analyze the `ScreenCapture` function."
* **Good**: "`ScreenCapture` 함수를 분석하겠습니다."

## 2.2 태스크 관리 (Task Boundary)
Task UI에 표시되는 상태 메시지도 한국어로 작성해야 합니다.
* **TaskName**: 작업의 제목
    - **Bad**: "Fix Screen Capture Bug"
    - **Good**: "스크린 캡처 버그 수정"
* **TaskStatus**: 현재 진행 중인 작업 상태
    - **Bad**: "Running build command..."
    - **Good**: "빌드 명령어를 실행 중입니다..."

## 2.3 음성 알림 (TTS)
`say` 명령어를 사용할 때는 영어 사용.

## 2.4 문서 (Artifacts)
* `Issue.md` 등 모든 문서는 한국어로 작성합니다.
* 단, 코드 블록 내부의 변수명/함수명은 영어로 유지합니다.

## 2.5 커밋 메시지 (Commit Messages)
* **Format**: `Type(Scope): Subject`
* **Example**: `Fix(Capture): 다중 모니터 캡처 오류 수정`

# 3. 예외 상황
* 코드 내의 **리터럴 문자열**이 프로그램 로직상 영어여야 하는 경우 (ex: URL, 프로토콜 상수)
* 외부 도구(GitHub CLI 등)의 명령어 인자가 영어만 허용하는 경우
