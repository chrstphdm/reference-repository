reference-repository
====================

**reference-repository** is Grid'5000's *single source of truth* about sites, clusters, nodes, and network topology.

There are several important parts:

* data/ is the set of JSON files that describe Grid'5000. They are exposed by the **reference API** (for example: `curl -k https://api.grid5000.fr/sid/sites/nancy/clusters/graoully/nodes/graoully-1.json?pretty` )
* input/ is the set of YAML files used to generate data/. The files in input/ are either:
    + manually created and edited by admins
    + generated by g5k-checks (this is the case of the nodes descriptions, in the nodes/ directory of each cluster)
* validators and generators
    + to check input/ data for consistency
    + to generate the configuration of various services (and the list of OAR properties)

All tasks are executed using **rake**. To see the list of tasks, use `rake -T`.

See also:

* https://www.grid5000.fr/mediawiki/index.php/Reference_Repository
* .gitlab-ci.yml, that automates various checks and the deployment of data files after each commit
* doc/README.generators.md

# Setup

We use bundler to manage dependencies.

```
apt install bundler
bundler install --standalone # this installs dependencies in the 'bundle' directory
rake reference-api # or other commands
```


# Credentials

all tools that require to authenticate against Grid'5000 use credentials from ~/.grid5000_api.yml. Example:
```
 uri: https://api.grid5000.fr/
 username: username
 password: password
 version: stable
```
