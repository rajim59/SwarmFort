
..

step-2

ssh -i ~/.ssh/id_rsa azureuser@85.211.196.111 "docker stack services swarmfort"

step-3
curl -k https://85.211.196.111/health

output: {"status":"ok"}

step-4
curl -I http://85.211.196.111

output: HTTP/1.1 301 Moved Permanently
        Location: https://85.211.196.111/

step-5
ssh -i ~/.ssh/id_rsa azureuser@85.211.196.111 "docker network inspect swarmfort_frontend-net | grep -i encrypted"

output: "encrypted": "true"

step-5
curl -k https://85.211.196.111/db-health

output: {"database":"connected"}

step-6
curl -v telnet://85.211.196.111:5432

output: সফল হওয়ার লক্ষণ: এই কমান্ডটি ডাটাবেজে কানেক্ট হতে পারবে না। 
        আপনি Connection refused বা Timeout মেসেজ দেখতে পাবেন। 
        এর মানে আপনার ডাটাবেজ বাইরের দুনিয়া থেকে ১০০% সুরক্ষিত! 
        (কমান্ডটি আটকে থাকলে Ctrl+C চেপে বের হয়ে আসবেন)।

step-7



