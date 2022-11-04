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
  - 30336 9933 9948 (for cess chain)
  - 15000 (for cess scheduler)
  - 15001 (for cess bucket)

```shell
sudo cess help
sudo cess start
sudo cess status
sudo cess logs chain
```

### Stop service

```shell
sudo cess stop
```

## License

[GPL v3](LICENSE)
