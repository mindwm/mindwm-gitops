import yaml
import file
import json_merge_patch as p

yaml_file_merge = lambda filename : str, patch : any {
    p.merge(yaml.decode(file.read(filename)), patch)
}
