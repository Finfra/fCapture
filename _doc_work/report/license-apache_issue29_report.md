---
name: license-apache_issue29_report
description: Issue29 라이선스 프로파일 A 적용 결과 — 파일 교체 내역·검증·tap 반영 명령(미실행)·후속 과제
date: 2026.09.27
issue: Issue29
---

# 요약

* PolyForm NC → **Apache-2.0** + 훅 ①상표(`TRADEMARK.md`) ②공식 배포본 약관(`DISTRIBUTION-TERMS.md` v1.1, N=250)
* 정본: `___architect/_doc_arch/license-profiles.md` §4 row 51 (A · ①②) — 파일 세트 §5 와 일치
* `git push`·`Finfra/homebrew-tap` 수정·릴리스 태그 변경은 **하지 않았다**

# 변경 파일

| 파일 | 내용 |
| :--- | :--- |
| [LICENSE](LICENSE) | Apache-2.0 원문 (apache.org, md5 `3b83ef96387f14655fc854ddc3c6bd57` — prj25 와 동일) |
| [LICENSE_ko.md](LICENSE_ko.md) | prj25 참고 번역 재사용 + 적용 범위 표를 fCapture 로 교체(v1.0.18 까지 배포본 PolyForm 유지 행 포함) |
| [NOTICE](NOTICE) · [TRADEMARK.md](TRADEMARK.md) · [DISTRIBUTION-TERMS.md](DISTRIBUTION-TERMS.md) · [COMMERCIAL.md](COMMERCIAL.md) | 템플릿 복사·자리표 채움 (`{{EFFECTIVE_DATE}}`=2026-09-27 · `{{YEAR}}`=2026 · `{{MARKS}}`=`the names "fCapture" and "fcapture"`) |
| [README.md](README.md) | 설치 절 안내 문구 + 라이선스 절 표(6개 파일 링크) + v1.0.18 이전 배포본 주석 |
| [Formula/fcapture.rb](Formula/fcapture.rb) | `license "Apache-2.0"` · caveats 약관 요약 · `prefix.install` 로 라이선스 문서 설치 (로컬만) |
| [deploy-brew.sh](deploy-brew.sh) | tarball 에 LICENSE·NOTICE·TRADEMARK·DISTRIBUTION-TERMS·COMMERCIAL 동봉 (Apache §4(a)(d) · 약관 §6 «inside the package») |
| [_doc_arch/brew-deploy-design.md](_doc_arch/brew-deploy-design.md) · [CLAUDE.md](CLAUDE.md) | 라이선스 표기 갱신, brew core 불가 전제 → «장벽 해소·등재 미결정» |

* `COMMERCIAL.md` 는 템플릿에서 두 곳을 조정했다 — 테마 행 삭제(fCapture 는 테마 없음), 상업 요구 조항 참조 `§3` → `§4`(v1.1 에서 상업 요구 목록은 §4)

# 검증

| 항목 | 결과 |
| :--- | :--- |
| 6개 파일 존재 + README 라이선스 절 링크 | 전부 Y (각 1회) |
| `grep -rn "All rights reserved" README*` | 0건 |
| 미치환 자리표 `{{…}}` | 0건 |
| `ruby -c Formula/fcapture.rb` · `bash -n deploy-brew.sh` | OK |
| 패키징 단계 격리 재현 (`tar -tzf`) | fcapture + 문서 5종 |

# tap 반영 명령 (미실행 — 다음 릴리스 때)

v1.0.18 tarball 은 PolyForm 시절 산출물이라 **지금 tap 의 `license` 만 바꾸면 기존 배포본을 오표기**한다. 다음 릴리스에서 로컬 formula 를 통째로 복사한다.

```bash
# 1. VERSION 올린 뒤 릴리스 (tarball 에 라이선스 문서 동봉됨)
./deploy-brew.sh
# 2. tap 반영 — 로컬 formula 전체 복사 (license "Apache-2.0" · caveats · prefix.install 포함)
cp Formula/fcapture.rb <homebrew-tap clone>/Formula/fcapture.rb
cd <homebrew-tap clone> && git commit -am "fcapture: Apache-2.0 + 공식 배포본 약관" && git push
# 3. 확인
brew update && brew info finfra/tap/fcapture | grep -i license
```

# 후속 과제 (이번 범위 밖)

* **공식 빌드 전용 구성요소 부재** — 템플릿 README ⚠️ · 정본 §3-2: Apache-2.0 §2 는 Object form 도 허락하므로 소스만 컴파일한 바이너리는 약관 §1(b) «Official Build Components» 가 빈 집합이다. 최소 1종(ex: `--version` 출력의 공식 빌드 브랜드 배너, 빌드 설정 주입)을 넣고 NOTICE 에 «Apache 대상 아님» 을 적어야 저작권 훅이 성립한다. 코드 변경이라 별도 이슈 권장
* **`CONTRIBUTING.md` 재라이선스 문장** — 정본 §5 마지막 불릿. 이슈 명세에 없어 미작성
* `_doc_arch/brew-deploy-design.md` → `brew-deploy.md` rename(naming-rules, rule-guard 알림) — 참조 10곳 모두 이 repo 내, rename 절차상 단독 커밋 대상이라 분리
* 템플릿 쪽 불일치(prj `___architect`): `COMMERCIAL.md` 가 v1.1 약관의 §4 가 아닌 §3 을 가리킴
