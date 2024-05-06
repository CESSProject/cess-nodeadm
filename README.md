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
  - 30336 9944 (for chain)
  - 19999 (for ceseal)
  - 15001 (for miner)

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
