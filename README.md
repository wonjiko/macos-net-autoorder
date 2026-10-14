# macos-net-autoorder

유선이 연결된 채로 느려지거나 패킷이 새면 Wi-Fi 같은 다른 회선으로 넘어가게 해 주는 macOS LaunchDaemon이다. macOS는 링크가 끊기거나 IP를 못 받을 때만 다른 회선으로 넘어가기 때문에, 이 스크립트가 5분마다 IPv4 주소가 있는 모든 네트워크 서비스에 ping을 보내고 손실률과 RTT가 확실히 나은 서비스를 서비스 순서 맨 위로 올린다.

```sh
git clone https://github.com/wonjiko/macos-net-autoorder.git
cd macos-net-autoorder
sudo ./install.sh
```

설치 전에 `./net-autoorder.sh --dry-run`을 실행하면 30초 동안 회선을 재고, 지금 바꿀 순서를 출력만 한다. 설치하고 나면 실행할 때마다 회선별 측정값과 순서를 바꿨는지가 `/var/log/net-autoorder.log`에 한 줄씩 남는다. 지울 때는 `sudo ./install.sh uninstall`을 실행한다.

launchd는 `~/Desktop` 같은 보호 폴더의 파일을 읽지 못해서, 설치 스크립트가 `net-autoorder.sh`를 `/usr/local/libexec`에 복사하고 그 복사본을 돌린다. 저장소에서 스크립트를 고쳤다면 `sudo ./install.sh`를 다시 실행해야 바뀐다.

## 순서를 자주 바꾸지 않는 이유

서비스 순서가 바뀌면 기본 경로가 다른 인터페이스로 넘어가면서 SSH나 화상회의 같은 연결이 끊긴다. 그래서 회선끼리 차이가 작으면 순서를 그대로 두고, 1순위 회선으로 트래픽이 많이 오가는 중이면 그 회차는 건너뛴다. 다만 1순위의 손실률이 크면 쓰는 중이어도 바꾼다. 망가진 회선에서도 재전송 트래픽은 계속 흐르기 때문에, 사용량만 보면 넘어갈 때를 놓친다.

기준값은 `net-autoorder.sh` 맨 위 변수에 있고, 바꾼 뒤에는 `./net-autoorder.sh --selftest`로 규칙을 확인할 수 있다.

## 주의할 점

- 휴대폰 USB 테더링도 후보에 들어가므로, 유선과 Wi-Fi가 함께 나빠지면 휴대폰 데이터로 넘어갈 수 있다.
- 대역폭은 재지 않는다. 손실률과 RTT가 비슷하면 더 빠른 회선이 있어도 넘어가지 않는다.
- ping 대상이 `1.1.1.1` 하나라서, 이 주소를 막은 네트워크에 연결된 회선은 실패로 나온다. 막히지 않은 Wi-Fi나 테더링이 함께 연결돼 있으면 그쪽이 1순위로 올라가고, 모든 회선이 막혀 있으면 순서를 바꾸지 않는다.
- 로그는 회전하지 않아 1년에 13MB쯤 쌓인다.
