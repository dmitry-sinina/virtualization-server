# Virtualization Server

This application provides a REST API that communicates with the libvirt daemon to create, modify, and delete virtual machines.

It assumes that you have libvirt installed and configured along the lines of [this](https://brooks.sh/2017/12/22/configuring-kvm-on-clear-linux/) blog post.

## API Documentation

### Virtual Machines

The `/virtual-machines/` namespace is where all CRUD operations for a virtual machine and their dependents live.

#### List all virtual machines

Request:

```
$ curl -s http://localhost:4567/api/virtual-machines -H "Accept: application/vnd.api+json"
```

Response:

```
200 OK
```

```json
[
  {
    "uuid": "2de02519-c347-432c-9923-3753c3538e02",
    "state": "shut off",
    "cpus": 2,
    "memory": 8388608
  }
]
```

#### View a single virtual machine

Request:

```
$ curl -s http://localhost:4567/api/virtual-machines/2de02519-c347-432c-9923-3753c3538e02 -H "Accept: application/vnd.api+json"
```

Response:

```
200 OK
```

```json
{
  "uuid": "2de02519-c347-432c-9923-3753c3538e02",
  "state": "shut off",
  "cpus": 2,
  "memory": 8388608
}
```

#### Create a virtual machine

Request:

```
$ curl -s http://localhost:4567/api/virtual-machines -X POST -d '{"cpus": 2, "memory": 8388608}' -H "Content-Type: application/vnd.api+json" -H "Accept: application/vnd.api+json"
```

Response:

```
201 Created
```

```json
{
  "uuid": "2de02519-c347-432c-9923-3753c3538e02",
  "state": "shut off",
  "cpus": 2,
  "memory": 8388608
}
```

#### Update a virtual machine

Request:

```
$ curl -s http://localhost:4567/api/virtual-machines/2de02519-c347-432c-9923-3753c3538e02 -X PATCH -d '{"state":"started"}' -H "Content-Type: application/vnd.api+json" -H "Accept: application/vnd.api+json"
```

##### Input

| Name | Type | Description |
|------|------|-------------|
| `state` | `string` | The state of the virtual machine. Can be one of `started`, `shutdown` (graceful), or `halted` (forced).

Response:

```
200 OK
```

```json
{
  "uuid": "2de02519-c347-432c-9923-3753c3538e02",
  "state": "started",
  "cpus": 2,
  "memory": 8388608
}
```

#### Destroy a virtual machine

Request:

```
$ curl -s http://localhost:4567/api/virtual-machines/2de02519-c347-432c-9923-3753c3538e02 -X DELETE  -H "Accept: application/vnd.api+json"
```

Response:

```
200 OK
```

## Setup

### Bootstrapping

```
git clone https://github.com/neptune-networks/virtualization-server
script/bootstrap
```

### Running the server

The server requires libvirt installed on your computer, assuming that you are running on a Mac, you should be able to get everything running by running:

```
brew install libvirt qemu
script/server
```

### Running tests

```
script/test
```
