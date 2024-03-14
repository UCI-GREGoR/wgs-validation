import random


def select_partition(partitionname: str, all_partitions: dict) -> str:
    """
    use a yaml string representation of a partition group and a configured
    yaml array of partition names to select partition targets for a rule resource
    """
    if partitionname in all_partitions.keys():
        return random.choice(all_partitions[partitionname])
    raise ValueError(
        "Configured partition set does not match anything in user resource config: {}".format(
            partitionname
        )
    )
