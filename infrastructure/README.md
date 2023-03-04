[comment]: # (ref https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html)
[comment]: # (ref https://awstip.com/this-code-works-kubernetes-cluster-autoscaler-on-amazon-eks-c2d059022e1c#7a7c)
**Prerequisites**

Before deploying the Cluster Autoscaler, you must meet the following prerequisites:
- An existing Amazon EKS cluster – If you don't have a cluster, see [Creating an Amazon EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html).
- An existing IAM OIDC provider for your cluster. To determine whether you have one or need to create one, see [Creating an IAM OIDC provider for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).
- Node groups with Auto Scaling groups tags. The Cluster Autoscaler requires the following tags on your Auto Scaling groups so that they can be auto-discovered.
    - If you used `eksctl` to create your node groups, these tags are automatically applied.
    - If you didn't use `eksctl`, you must manually tag your Auto Scaling groups with the following tags. For more information, see [Tagging your Amazon EC2 resources](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_Tags.html) in the Amazon EC2 User Guide for Linux Instances.
        - `k8s.io/cluster-autoscaler/enabled` – Set to `true` to enable the Cluster Autoscaler to scale the node group.
        - `k8s.io/cluster-autoscaler/CLUSTER_NAME` – Set to `owned`. Replace `CLUSTER_NAME` with your own value.

**Create an IAM policy and role**

1. Open the IAM console at https://console.aws.amazon.com/iam/.
2. In the left navigation pane, choose **Roles**. Then choose **Create role**.
3. In the **Trusted entity type** section, choose **Web identity**.
4. In the **Web identity** section:
    - For **Identity provider**, choose the **OpenID Connect provider URL** for your cluster (as shown in the cluster **Overview** tab in Amazon EKS).
    - For **Audience**, choose `sts.amazonaws.com`.
5. Choose **Next**.
6. For **Role name**, enter a unique name for your role, such as **`AmazonEKSClusterAutoscalerRole`**.
7. For **Description**, enter descriptive text such as **`Amazon EKS - Cluster autoscaler role`**.
8. Choose **Create role**.
9. After the role is created, choose the role in the console to open it for editing.
10. Choose the **Trust relationships** tab, and then choose **Edit trust policy**.
11. Find the line that looks similar to the following:
    ```
    "oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com"
    ```
    Change the line to look like the following line. Replace `EXAMPLED539D4633E53DE1B71EXAMPLE` with your cluster's OIDC provider ID. Replace `region-code` with the AWS Region that your cluster is in.
    ```
    "oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:kube-system:cluster-autoscaler"
    ```
12. Choose **Update policy** to finish.

**Deploy cluster autoscaler**
1. Download the Cluster Autoscaler YAML file.

    ```
    curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
    ```

2. Modify the YAML file and replace **YOUR CLUSTER NAME** with your cluster name. Also consider replacing the `cpu` and `memory` values as determined by your environment.

3. Apply the YAML file to your cluster.

    ```
    kubectl apply -f cluster-autoscaler-autodiscover.yaml
    ```

4. Annotate the `cluster-autoscaler` service account with the ARN of the IAM role that you created previously. Replace the **example values** with your own values.

    ```
    kubectl annotate serviceaccount cluster-autoscaler \
    -n kube-system \
    eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/AmazonEKSClusterAutoscalerRole
    ```

5. Patch the deployment to add the `cluster-autoscaler.kubernetes.io/safe-to-evict` annotation to the Cluster Autoscaler pods with the following command.

    ```
    kubectl patch deployment cluster-autoscaler \
    -n kube-system \
    -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'
    ```

6. Edit the Cluster Autoscaler deployment with the following command.

    ```
    kubectl -n kube-system edit deployment.apps/cluster-autoscaler
    ```

    Edit the `cluster-autoscaler` container command to add the following options. `--balance-similar-node-groups` ensures that there is enough available compute across all availability zones. `--skip-nodes-with-system-pods=false` ensures that there are no problems with scaling to zero.

    - `--balance-similar-node-groups`

    - `--skip-nodes-with-system-pods=false`

    ```
    spec:
      containers:
      - command
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/my-cluster
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
    ```

    Save and close the file to apply the changes.

7. Open the [Cluster Autoscaler releases](https://github.com/kubernetes/autoscaler/releases) page from GitHub in a web browser and find the latest Cluster Autoscaler version that matches the Kubernetes major and minor version of your cluster. For example, if the Kubernetes version of your cluster is `1.25`, find the latest Cluster Autoscaler release that begins with `1.25`. Record the semantic version number (`1.25.n`) for that release to use in the next step.

8. Set the Cluster Autoscaler image tag to the version that you recorded in the previous step with the following command. Replace `1.25.n` with your own value.

    ```
    kubectl set image deployment cluster-autoscaler \
    -n kube-system \
    cluster-autoscaler=registry.k8s.io/autoscaling/cluster-autoscaler:v1.25.n
    ```

**View Cluster Autoscaler logs**

    
    kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
    

**Test Cluster Autoscaler - Scale Out**
1. Create a simple pod with nginx container
    
    ```
    kubectl create deploy nginx --image nginx
    ```

2. Confirm pod running

    ```
    kubectl get pods -o wide
    ```

3. Watch the status of nodes (in a separate terminal window)

    ```
    kubectl get nodes -o wide --watch
    ```

4. Increase the number of replicas

    ```
    kubectl scale deployment nginx --replicas=96
    ```

5. Watch the podes running state with 96 replicas

    ```
    kubectl get pods -o wide
    ```

**Test Cluster Autoscaler - Scale In**
1. Ratchet down pod size back to original

    ```
    kubectl scale deployment nginx --replicas=1
    ```

2. Delete the pod

    ```
    kubectl get pods  --no-headers=true | awk '/nginx/{print $1}' | xargs  kubectl delete pod
    ```

3. Delete the deployment

    ```
    kubectl delete deploy nginx
    ```

4. Watch the nodes scale down

    ```
    kubectl get nodes -o wide
    ```

    Cluster Autoscaler decreases the size of the cluster when some nodes are consistently unneeded for a significant amount of time.
    A node is unneeded when it has low utilization and all of its important pods can be moved elsewhere.

**Clean up**
1. Detach the policy we had manually attached to the Cluster Role

    ```
    aws iam detach-role-policy \
    --role-name AmazonEKSClusterAutoscalerRole \
    --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/AmazonEKSClusterAutoscalerPolicy
    ```

2. Delete the IAM role

    ```
    aws iam delete-role --role-name AmazonEKSClusterAutoscalerRole
    ```

3. Destroy the infrastructure

    ```
    terraform destroy
    ```