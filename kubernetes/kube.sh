kubectl delete job concurrent-insertion-test --ignore-not-found=true

kubectl apply -f concurrent-test.yaml 


kubectl wait --for=condition=complete job/concurrent-insertion-test --timeout=60s

POD_NAME=$(kubectl get pods -l job-name=concurrent-insertion-test --field-selector=status.phase!=Running,status.phase!=Pending -o jsonpath='{.items[0].metadata.name}')

kubectl logs $POD_NAME






kubectl run -it test-ping1 --rm --image=busybox -- ping -c 3 mariadb-master1

kubectl run -it test-ping2 --rm --image=busybox -- ping -c 3 mariadb-master2