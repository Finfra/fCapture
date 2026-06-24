---
name: PROMPTS
description: fCapture 프로젝트 프롬프트 모음
date: 2026-06-18
---

# 자주쓰는 프롬프트 모음

## 캡처·릴레이
* `{머신}/Relay.json 릴레이 파일 만들어줘. 주변 파일 참고.`
* `~/.fCapture/{머신}에도 생성.`
* `{yml} 파일로 동작시키는데 흐름이 어떻게 되지?`

## Git·문서
* `git add하고 커밋해야 할 내용 보여줘.`
* `git commit and push`
* `채팅 히스토리 뒤져서 업데이트해줘. @{경로}`

# 테스트
*기본 테스트
```
```



# ToDay prompts History
## 2026.03.27
```
00_default.json
01_screen1.json
02_screen2.json
03_screen123.json
04_screenAll.json
05_region_static.json
06_region_user.json
07_window_active.json
08_window_pointer.json
11_option_basePath.json
12_option_capturePathArray0.json
13_option_capturePathArray1.json
14_option_backupOtherScreen.json
15_option_shadow_false.json
16_option_shadow_true.json
17_option_result_text.json
18_option_result_json.json
19_option_result_onlyPath.json

./bin/fCapture data/settings/00_default.json
./bin/fCapture data/settings/02_screen2.json
./bin/fCapture data/settings/04_screenAll.json
./bin/fCapture data/settings/06_region.json
./bin/fCapture data/settings/08_window_mouse.json
./bin/fCapture data/settings/01_screen1.json
./bin/fCapture data/settings/03_screen3.json
./bin/fCapture data/settings/05_region_static.json
./bin/fCapture data/settings/07_window_active.json
./bin/fCapture data/settings/10_basePath.json
./bin/fCapture data/settings/11_option_Shadow_true.json
./bin/fCapture data/settings/12_option_Shadow_false.json
zz_backup_screen1.json

~/.fCapture/config.json

cat > ./bin/fCapture << 'EOF'
#!/bin/zsh
DIR="${0:A:h}"
"$DIR/../fCapture/.build/arm64-apple-macosx/release/fCapture" "$@"
EOF
chmod +x ./bin/fCapture
./bin/fCapture

~_doc/1.Area/_memo/t4.jCapture.json
/Users/nowage/Library/Mobile Documents/iCloud~md~obsidian/Documents/_doc/1.Area/_memo/t4.jCapture.json

용어 수정 되었음. /Users/nowage/_git/__all/fCapture/data/settings 기준. screen,region,window으로 용어 통일하고, shadow는 스킨샷 찍을때 그림자 넣느냐마느냐 인데 os에서는 true가 기본 값이나 앱에서는 false가 기본값임.  active도 window로 수정했는데, 현재 마우스 위치에 있는 윈도우의 active윈도우로만들어서 스키린 샷 찍는 기능 때문임. 모든 문서와 코드 수정해주고, _doc_arch/Glossary.md에 저장해하고 팀을 이뤄서 구현해줘.
1. 관리자.
2. 개발자*3
3. 문서 관리자.
4. qa(/run으로실행해서 settings 옵션을 적용해서 data/result/저장하고 잘 되었는지 확인)
5. harness manager(.claude를 다른 프로젝트에서 가져옴. skill이나 커맨드 오작동시 수정)


/dev 아래 앱 옵션 추가해줘. 이슈 생성하고 서브이슈를 접근하는 방식으로 팀을 구성해서 구현해줘. 
1. ""                 : 없으면 defaultSetting.json으로 실행됨(이미 구현, 검토만)
2. "--help"           : Usage, 사용법, 만든 사람 등을 추가. 
3. "-s","--screen"    : defaultWindow.json으로 캡처
4. "-r","--region"    : defaultRegion.json으로 캡처
5. "-w","--window"    : defaultScreen.json으로 캡처
6. "-f","--fixRegion" : 마지막 region_user 타겟으로 캡쳐한 좌표를 defaultRegion.json에 적용함. [region_user 타겟으로 캡처하면 info_stateManager.json에 저장하는 기능 필요. info_stateManager.json 정보 없으면 secreen1의 전체를 저장하는 기능도 필요(에러방지)]
7. Usage정리해서 noteForHuman.md와  README.md에 추가. 


_doc_work/report/fapp-capture-CASR.md를 참고해서 _doc_work/plan/fapp-capture-plan.md를 만들어줘.  팀을 구성해서 아래 조건으로 구현.  코드를 절대 수정하면 않되고, _doc_work/plan/fapp-capture-plan.md를 만드는 것이 목적임. 

0. 팀을 구성해서 plan파일을 통해 실제 구현 할 것을 상정하고 plan파일 생성.
1. _doc_work/report/fapp-capture-CASR.md를 기반으로 fBanner프로젝트를 개선할 방법이 있다면 개선한다. 
2. fBanner에서 실제 테스트를 진행하고, data/UI/UI_list.yml에 따라 캡처가 잘 작동하는지 확인한다. 
3. fapp모두 data/UI/UI_list.yml가 있으니 이를 fBanner를 기반으로 업데이트한다. 
4. fapp의 모든 앱의 모든 윈도우 구현 코드를 비교하여 data/UI/UI_list.yml를 업데이트 한다. 
5. _doc_work/tmp_CASR에 기존 캡처 관련 {agents,skills,commands,rules}와 관련 스크립트를 이동 시킴(fBanner제외)
6. fBanner의 {agents,skills,commands,rules}와 관련 스크립트를 나머지 fapp에 복사함.
7. 각 프로젝트에 최적화 시킴. 
8. 각 프로젝트에서 작동 테스트. 



fSnippet에서 .agent/skills/capture/scripts/capture.sh를 .claude/skills/capture/scripts/capture.sh으로 이동했는데 plan에는 별 문제 없나?
```

