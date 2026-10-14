# macos-net-autoorder

유선이 연결된 채로 패킷 손실이 생기거나 응답이 느려지면 Wi-Fi 같은 다른 회선으로 넘어가게 해 주는 macOS LaunchDaemon이다. macOS는 링크가 끊기거나 IP를 못 받을 때만 다른 회선으로 넘어가기 때문에, 이 스크립트가 5분마다 IPv4 주소가 있는 모든 네트워크 서비스에 ping을 보내고 손실률과 RTT가 확실히 나은 서비스를 서비스 순서 맨 위로 올린다.

```sh
git clone https://github.com/wonjiko/macos-net-autoorder.git
cd macos-net-autoorder
sudo ./install.sh
```

설치 전에 `./net-autoorder.sh --dry-run`을 실행하면 30초 동안 회선을 재고, 지금 바꿀 순서를 출력만 한다. 설치하고 나면 실행할 때마다 회선별 측정값과 순서를 바꿨는지가 `/var/log/net-autoorder.log`에 한 줄씩 남는다. 지울 때는 `sudo ./install.sh uninstall`을 실행한다.

launchd는 `~/Desktop` 같은 보호 폴더의 파일을 읽지 못해서, 설치 스크립트가 `net-autoorder.sh`를 `/usr/local/libexec`에 복사하고 그 복사본을 돌린다. 판정 기준값은 `net-autoorder.sh` 맨 위 변수에 있다. 스크립트를 고쳤다면 `./net-autoorder.sh --selftest`로 규칙을 확인한 뒤 `sudo ./install.sh`를 다시 실행해야 바뀐다.

## 주의할 점

- 순서가 바뀌면 기본 경로가 다른 인터페이스로 넘어가서 SSH나 화상회의 같은 연결이 끊긴다. 그래서 회선끼리 차이가 작거나 1순위 회선으로 트래픽이 많이 오가는 중이면 순서를 그대로 두고, 1순위의 손실률이 클 때만 쓰는 중이어도 바꾼다.
- 휴대폰 USB 테더링도 후보에 들어가므로, 유선과 Wi-Fi가 함께 나빠지면 휴대폰 데이터로 넘어갈 수 있다.
- 대역폭은 재지 않는다. 손실률과 RTT가 비슷하면 더 빠른 회선이 있어도 넘어가지 않는다.
- ping 대상이 `1.1.1.1` 하나라서, 이 주소를 막은 네트워크에 연결된 회선은 실패로 나온다. 막히지 않은 Wi-Fi나 테더링이 함께 연결돼 있으면 그쪽이 1순위로 올라가고, 모든 회선이 막혀 있으면 순서를 바꾸지 않는다.
- 로그가 10MB를 넘으면 macOS의 newsyslog가 직전 로그를 `net-autoorder.log.0.bz2` 하나로 압축해 두고 새로 쓰기 시작한다.
