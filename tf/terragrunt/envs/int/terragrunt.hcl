include {
    path = find_in_parent_folders()
}

terraform {
    source = "../../../..//tf/pyecho"
}

inputs = {
    env = "internal"
    app_name = "pyecho-int"
    helm_release_version = "1.0.0"
    cluster_name = "pyecho-cluster-int"
}