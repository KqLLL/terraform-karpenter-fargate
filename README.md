# introduce
Here is an example of an EKS cluster built by terraform. 
Karpenter and Fargate as compute nodes.
## Use
```shell
cd workspace/
terraform apply -var access_key=$YOUR_ACCESS_KEY -var secret_key=$YOUR_SECRET_KEY

##You need to manually change CoreDNS according to the following documentation
## ref: https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html#fargate-sg-pod-execution-role
aws --profile sandbox eks update-kubeconfig --name sandbox

## This command will deploy coredns to fargate.
kubectl patch deployment coredns \
    -n kube-system \
    --type json \
    -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
```
## Test
The **example** directory provides some examples for testing the availability of the cluster.
It will deploy a traefik ingress controller to the EKS cluster.
```shell
## Define karpenter provisioner CR.
kubectl apply -f example/kubernetes/karpenter/provisioner.yaml

cd example/helmfile
## helmfile ref: https://github.com/roboll/helmfile
helmfile apply
```