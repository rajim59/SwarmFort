# আপনার আগে তৈরি করা টোকেনটি এখানে বসান (ম্যানুয়ালি একবার)
TOKEN = SWMTKN-1-2q9ghacht6rimmoeqahv6e76izziyhy95vtcam7kp0ihkz6fa8-1lu27w92iauhpw2ykf0olj5le
MANAGER_IP = 192.168.65.3

# নোড জয়েন করার জন্য প্রফেশনাল রুল
join-nodes:
	@echo "Joining nodes to the cluster..."
	ssh root@swarm-manager-2 'docker swarm join --token $(TOKEN) $(MANAGER_IP):2377'
	ssh root@swarm-manager-3 'docker swarm join --token $(TOKEN) $(MANAGER_IP):2377'
	ssh root@swarm-worker-1 'docker swarm join --token $(TOKEN) $(MANAGER_IP):2377'
	ssh root@swarm-worker-2 'docker swarm join --token $(TOKEN) $(MANAGER_IP):2377'
	ssh root@$(MANAGER_IP) 'docker node ls'