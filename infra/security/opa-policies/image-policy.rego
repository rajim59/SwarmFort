package main

deny[msg] {
    input.Labels["com.example.sec-approved"] != "true"
    msg = "Image missing required security approval label"
}