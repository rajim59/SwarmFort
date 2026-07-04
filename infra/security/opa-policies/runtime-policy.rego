package docker.runtime

import rego.v1

default allow := false

# ক্যাপাবিলিটি ড্রপ ও নির্দিষ্ট কিছু অ্যালাউ চেক
allow if {
    input.Container.Capabilities.Drop[_] == "ALL"
    count(input.Container.Capabilities.Add) == 0
}

# read_only_rootfs সত্য হতে হবে
allow if {
    input.Container.ReadOnlyRootfs == true
}

# no-new-privileges অবশ্যই চালু
allow if {
    input.Container.NoNewPrivileges == true
}