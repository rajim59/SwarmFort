package main

deny[msg] {
    not input.HostConfig.ReadonlyRootfs
    msg = "Container must have read-only rootfs"
}

deny[msg] {
    input.HostConfig.Privileged == true
    msg = "Privileged containers are not allowed"
}