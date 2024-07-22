include {
    path = find_in_parent_folders()
}

terraform {
    source = "../../../..//tf/pyecho"
}

inputs = {
    env = "dev"
    helm_release_version = "1.0.0"
    app_name = "pyecho2"
    cluster_name = "pyecho2-cluster"
}
