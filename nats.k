config = {
    cluster.merge.name = "nats-cluster"
    jetstream.enable = True
    merge.accounts = {
        "$SYS.users" = {
	        user = "sys"
	        password = "pass"
        }
        root = {
            jetstream = "enable"
            user = "sys"
            password = "pass"
        }
    }
}

