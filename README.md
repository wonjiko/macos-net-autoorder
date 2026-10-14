# macos-net-autoorder

유선이 꽂혀 있으면 macOS는 패킷이 새고 느려져도 그 유선을 놓지 않는다. 서비스 순위를 내리는 조건이 링크 끊김, IP 없음, 라우터 무응답뿐이라 손실과 지연은 보지 않기 때문이다. 이 스크립트는 5분마다 IPv4 주소가 있는 모든 회선에 ping을 보내고, 확실히 나은 회선을 네트워크 서비스 순서 맨 위로 올린다.

규칙을 직접 돌려 보는 설명 페이지는 https://wonjiko.github.io/macos-net-autoorder/ 에 있다.

## 설치

```sh
git clone https://github.com/wonjiko/macos-net-autoorder.git
cd macos-net-autoorder
./net-autoorder.sh --dry-run   # 30초 동안 재고, 바꿀 순서만 출력한다
sudo ./install.sh
```

서비스 순서를 바꾸려면 root 권한이 필요해서 LaunchDaemon으로 설치된다. launchd는 `~/Desktop` 같은 보호 폴더의 파일을 읽지 못하므로 스크립트를 `/usr/local/libexec`에 복사해 두고 돌린다. 그래서 저장소에서 스크립트를 고쳤다면 `sudo ./install.sh`를 다시 실행해야 실제로 도는 쪽에 들어간다. 지울 때는 `sudo ./install.sh uninstall`.

실행할 때마다 `/var/log/net-autoorder.log`에 회선별 손실률과 RTT, 순서를 바꿨는지가 한 줄씩 남는다.

## 순서를 자주 바꾸지 않는 이유

순서가 바뀌면 기본 경로가 다른 인터페이스로 넘어가서 SSH나 화상회의 같은 연결이 끊긴다. 그래서 회선끼리 차이가 작으면 지금 순서를 그대로 두고, 1순위 회선으로 트래픽이 많이 오가는 중이면 그 주기는 건너뛴다. 1순위의 손실률이 크면 쓰는 중이어도 바꾼다. 망가진 회선에서도 재전송 트래픽은 계속 흐르니, 사용량만 보고 미루면 영영 넘어가지 못한다.

대역폭은 재지 않는다. 회선마다 파일을 받아 보려면 5분마다 트래픽이 크게 나가고, 휴대폰 테더링이면 요금까지 붙는다.

기준값은 `net-autoorder.sh` 맨 위 변수에 있다. 바꾼 뒤에는 `./net-autoorder.sh --selftest`로 규칙이 의도대로 도는지 확인할 수 있다.

## 알고 쓸 것

- ping 대상이 `1.1.1.1` 하나라서, 이 주소를 막는 네트워크에서는 모든 회선이 실패로 나와 아무것도 바꾸지 않는다.
- 테더링도 후보에 들어간다. 유선과 Wi-Fi가 같이 나빠지면 휴대폰 데이터로 넘어갈 수 있다.
- 로그는 회전하지 않고, 1년에 13MB쯤 쌓인다.
