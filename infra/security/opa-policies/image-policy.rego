package docker.image

import rego.v1

# ডিফল্ট অস্বীকার
default allow := false

# ইমেজ লেবেল com.example.sec-approved=true থাকতে হবে
allow if {
    input.Image.Labels["com.example.sec-approved"] == "true"
}

# DCT সাইনিং বা Cosign ভেরিফিকেশন নিশ্চিত
allow if {
    input.Image.Signatures[_].signed == true
}