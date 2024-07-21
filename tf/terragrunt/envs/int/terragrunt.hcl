include {
    path = find_in_parent_folders()
}

terraform {
    source = "../../../..//tf/pyecho"
}

inputs = {
    env = "internal"
    helm_release_version = "0.0.22"
}
