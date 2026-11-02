# 터치패드 음량 (touchpad-volume)

맥북 트랙패드에 **네 손가락을 올리고 위/아래로 쓸면 음량이 바뀌는** 작은 macOS 앱입니다.

- 위로 쓸면 음량 업, 아래로 쓸면 음량 다운
- 네 손가락이 닿아 있는 동안에는 스크롤이 막혀서 화면이 같이 움직이지 않습니다
- 화면에 보이는 창이나 아이콘이 없습니다. 바뀐 음량은 메뉴 막대의 소리 아이콘이나 제어 센터에서 확인하세요
- 로그인하면 자동으로 켜집니다

## 필요한 것

- macOS 15 (Sequoia) 이상
- 트랙패드가 있는 맥북 (내장 트랙패드 기준)
- Xcode Command Line Tools: 소스에서 바로 빌드하기 때문에 필요합니다

## 설치

터미널을 열고 아래를 차례로 붙여 넣으세요.

```bash
# 1. Command Line Tools (처음 한 번. 이미 설치돼 있으면 "already installed" 라고 나오고 끝)
xcode-select --install

# 2. 받아서 빌드하고 실행
git clone https://github.com/hidudu0/touchpad-volume.git
cd touchpad-volume
bash 시작.command
```

`bash 시작.command` 한 줄이 빌드, 자체 점검, 실행까지 모두 합니다. 소스가 바뀌었을 때만 다시 빌드합니다.

ZIP 으로 받았다면 압축을 푼 폴더에서 `bash 시작.command` 를 실행하세요. Finder 에서 더블클릭하면 "확인되지 않은 개발자" 경고로 막힐 수 있습니다.

## 처음 한 번 설정

### 1. 손쉬운 사용 권한 허용

처음 실행하면 권한 요청 창이 뜹니다.
**시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용** 에서 **터치패드** 를 켜세요.
켜고 나면 앱을 다시 실행할 필요 없이 2초 안에 적용됩니다.

이 권한은 네 손가락일 때 스크롤을 막는 데만 씁니다. 권한이 없어도 음량 조절은 되지만, 쓸 때 화면이 같이 스크롤됩니다.

### 2. 네 손가락 위/아래 제스처 끄기

Mission Control(위로 쓸기)과 앱 Exposé(아래로 쓸기)가 네 손가락에 걸려 있으면 음량과 같이 동작합니다.
설정 화면에서 세 손가락을 골라도 네 손가락 쪽이 같이 켜진 채 남을 수 있어서, 아래 명령으로 맞춥니다.
세 손가락 위/아래는 Mission Control·앱 Exposé, 네 손가락 위/아래는 꺼짐이 됩니다.

```bash
for d in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  defaults write $d TrackpadThreeFingerVertSwipeGesture -int 2
  defaults write $d TrackpadFourFingerVertSwipeGesture -int 0
done
defaults -currentHost write -g com.apple.trackpad.threeFingerVertSwipeGesture -int 2
defaults -currentHost write -g com.apple.trackpad.fourFingerVertSwipeGesture -int 0
defaults write com.apple.dock showMissionControlGestureEnabled -bool true
defaults write com.apple.dock showAppExposeGestureEnabled -bool true
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
killall Dock
```

세 손가락 제스처는 **세 손가락으로 드래그** 가 켜져 있으면 동작하지 않습니다. 쓰려면 **시스템 설정 → 손쉬운 사용 → 포인터 제어 → 트랙패드 옵션** 에서 끄세요.
나중에 **시스템 설정 → 트랙패드** 에서 제스처를 다시 고르면 네 손가락이 다시 켜질 수 있습니다. 그때는 위 명령을 한 번 더 실행하세요.

## 사용법

| 동작 | 결과 |
|---|---|
| 네 손가락 올리고 위로 쓸기 | 음량 업 |
| 네 손가락 올리고 아래로 쓸기 | 음량 다운 |
| 네 손가락 좌우로 쓸기 | 무시 |
| 두 손가락 스크롤 | 평소대로 |

- 손가락을 올린 순간의 음량이 기준입니다. 트랙패드 높이의 2/3 정도를 쓸면 0% → 100% 입니다.
- 음소거 상태에서 쓸면 음소거가 풀립니다.

### 감도 조절

`TouchPad.swift` 맨 위 두 값을 고친 뒤 `bash 시작.command` 를 다시 실행하세요.

```swift
let gain = 1.5     // 클수록 조금만 쓸어도 많이 바뀜
let flipY = false  // 위아래가 반대로 먹으면 true
```

다시 빌드하면 손쉬운 사용 권한이 풀립니다. 서명이 바뀌어 macOS 가 다른 앱으로 보기 때문이고, 목록에는 켜진 채로 보여도 동작하지 않습니다. 아래를 실행한 뒤 뜨는 창에서 다시 허용하세요.

```bash
tccutil reset Accessibility local.touchpad.volume
bash 시작.command
```

## 끄기 / 삭제

```bash
pkill touchpad   # 지금 끄기 (다음 로그인 때 다시 켜짐)
```

- 자동 실행 끄기: **시스템 설정 → 일반 → 로그인 항목** 에서 **터치패드** 끄기
- 완전히 지우기
  1. `pkill touchpad`
  2. 로그인 항목에서 터치패드 제거
  3. `tccutil reset Accessibility local.touchpad.volume` (손쉬운 사용 권한 제거)
  4. `defaults delete local.touchpad.volume`
  5. 폴더 삭제

## 주의사항

- **비공개 API 사용**: 손가락 위치를 읽으려고 Apple 의 비공개 프레임워크 `MultitouchSupport` 를 씁니다. macOS 업데이트 후 갑자기 동작하지 않을 수 있습니다.
- **네 손가락 스크롤 전부 차단**: 네 손가락이 닿아 있는 동안에는 어떤 앱에서도 스크롤이 되지 않습니다. 네 손가락 스크롤을 쓰는 분은 이 앱과 같이 쓸 수 없습니다.
- **트랙패드 하나만 인식**: 시스템 기본 트랙패드(맥북 내장) 하나만 봅니다. 외장 Magic Trackpad 는 동작하지 않을 수 있습니다.
- **음량 조절이 안 되는 출력 장치**: HDMI/DisplayPort 모니터 스피커처럼 macOS 에서 음량 슬라이더가 비활성화되는 장치에서는 동작하지 않습니다.
- **앱 폴더 옮기기**: 로그인 자동 실행은 처음 실행한 위치를 기억합니다. 폴더를 옮겼다면 새 위치에서 `bash 시작.command` 를 한 번 실행하세요.
- **잠자기 후**: 잠자기에서 깨면 2초 뒤 트랙패드에 다시 연결합니다. 그래도 안 되면 `bash 시작.command` 를 다시 실행하세요.
- **하는 일은 이것뿐**: 네트워크 통신이 없고, 키 입력을 읽지 않으며, 가로채는 이벤트는 스크롤뿐입니다. 코드는 `TouchPad.swift` 한 파일(약 180줄)이니 실행 전에 직접 확인해 보셔도 됩니다.

## 테스트 환경

macOS 26.6, Apple Silicon 맥북 내장 트랙패드

## 라이선스

MIT
