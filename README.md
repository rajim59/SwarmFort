
az group delete --name swarmfort-resources --yes

az account list-locations --query "[?metadata.regionCategory=='Recommended'].{DisplayName:displayName, Name:name}" -o table

docker-compose -f infra/docker/docker-compose.yml up -d

az group delete --name swarmfort-resources --yes --no-wait

az policy assignment list --query "[?contains(displayName, 'Allowed')].parameters.listOfAllowedLocations.value[]" -o tsv


make infra-up
















