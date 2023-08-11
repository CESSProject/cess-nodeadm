# cess node
Official cess node service for running cess protocol.

## Install dependencies

### Install cess service
```shell
sudo ./install.sh # Use 'sudo ./install.sh
```

### Modify config.yaml
```shell
sudo cess config set
```

### Run service

- Please make sure the following ports are not occupied before starting：
  - 30336 9933 9948 (for chain)
  - 10010 (for kld-agent)
  - 4001 (for kld-sgx)
  - 15001 (for bucket)

```shell
sudo cess help
sudo cess start
sudo cess status
sudo docker logs -f chain
```

### Stop service

```shell
sudo cess stop
```

## License

[GPL v3](LICENSE)
