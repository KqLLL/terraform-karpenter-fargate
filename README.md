# introduce
Here is an example of an EKS cluster built by terraform. 
Karpenter and Fargate as compute nodes.
## Use
```shell
cd workspace/
terraform apply -var access_key=$YOUR_ACCESS_KEY -var secret_key=$YOUR_SECRET_KEY
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