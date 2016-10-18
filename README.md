# LibRank::Demonstrator::API

Server component of the LibRank demonstrator.

## Description

This repository contains the code for the API that is used by the
[LibRank-Demonstrator](http://librank-demo.zbw.eu). 
The [UI component](https://github.com/LibRank-Project/LibRank-Demonstrator-UI)
uses the API to get some basic data about tasks, features, and 
predefined rankings. The main purpose of the API is to determine the result 
lists and performance for the tasks for custom model/feature weights 
provided by the user. The actual calculation is done by the `Model` objects in 
[LibRank::Ranker](https://github.com/LibRank-Project/LibRank-Ranker).


## Deployment

First, setup the API and install the dependencies:

```
git clone https://github.com/LibRank-Project/LibRank-Demonstrator-API
cd LibRank-Demonstrator-API
cpanm --installdeps .

cpanm https://github.com/LibRank-Project/LibRank-Measure.git
cpanm https://github.com/LibRank-Project/LibRank-Ranker.git
cpanm https://github.com/LibRank-Project/LibRank-Task.git
```

If you want to setup your own version of the API you will need to provide some
additional data and setup some services in `conf/services.pl` (using [Bread::Board](https://metacpan.org/pod/Bread::Board)).


### Tasks

List of all tasks. This is used to populate the tasks panel and the result list panel in the UI. A task object looks like

```
{
  "SearchTask": <task-id>,
  "run": <run-id>,
  "desc": <description of the task>,
  "query": <query>
}
```

The default configuration expects a JSON file with one task object per line in `data/tasks.json` (service `tasks`).

### Features

The configured features are used to render the feature selection dialog in the UI.
Features are arranged in a hierarchy. Each node in the hierachry looks like

```
{
  "description": <description of the feature group>,
  "label": <label for the group>,
  "level": <level in the hierarchy>,
  "items": [ <group node or feature>, ... ],
  "show": <if true expand group by default>,
  "hide": <if true do not show this branch in the view>,
  "uuid": <unique node id; used to bind toggle handler in the view>,
}
```

The actual features are the leafs of this tree:

```
{
  "key": <key of the feature; is used to set corresponding weight in the ranking model>,
  "label": <short label for the feature>,
  "description": <description of the feature>,
  "hide": <if true do not show this feature in the view>
}
```

The default configuration expects a JSON file in `data/features.json` (service `features`) that contains a single JSON array ([ group-1, group-2, ...]). 

### Predefined rankings

The predefined rankings are used to populate the ranking selection dialog in the view.
A ranking object looks like

```
{
  "name": <label for the ranking model>,
  "description": <description of the model>,  
  "normalize_weights": <if true normalize sum of the weights to one; this only applies to pOWAv1 models>,
  "ranking": <model type: (pOWAv1|EconBiz)>,
  "solr": [ <weights used to determine the text score> ],
  "weights": [ <query independent parameter/weights> ]
}
```

The solr weights look like

```
{
  "key": "solr/<solr param>/<solr field>", // e.g. "solr/pf/title"
  "value": 10
}
```

The query independent weights are similar

```
{
  "key": <key of the feature>,
  "value": 1.5
}
```

The `weights` array also contains the setting for the scaling factor for the query independent scores.

```
{
  "key": "lr_w_qi",
  "value": 100
}
```
The key is hard coded.

The default configuration expects a JSON file in `data/rankings.json` (service `rankings`) that contains a single JSON object (w/o line breaks):
```
{
  description: ...,
  runs: [
    {
      description: ...,
      run: <run id>,
      rankings: [ <ranking-1>, ... ]
    }
  ]
}
```


### Solr

The rankers extract the text scores from a solr instance. You will probably need to provide your own `text_scorer` service to adjust for your local needs.
See the `text_scorer` service and the `WebService::Solr` service in
`LibRank::Demonstrator::API::Services` as a starting point.

The default configuration also uses solr to retrieve the metadata for the records. The metadata 
is only used to populate the result list in the UI. You will probably need to provide your own
service for `record_manager` to adjust for your local needs. See `LibRank::Demonstrator::API::RecordManager::Solr`
for a simple implementation.

The view expects the following metadata for a record
```
{
  id: <id>,
  title: [ <title>, ... ],
  date: [ <year of publication>, ... ],
  creator: [ <string>, ... ],
  type: (article|book|...),
  source: <string; source database of the record>
}
```

### Feature data and relevance judgments

Finally, you need to provide the actual data used to determine the rankings of 
documents and the performance of a task, i.e. the feature data and the relevance judgments. In the default configuration this data is provided by the `task_data` service to initialize the `task_manager` service.

The `task_data` service should provide a perl array with

```
{
  run => <run id>,
  tasks => [ <task>, ... ]
}
```
A task object ([LibRank::Task](https://github.com/LibRank-Project/LibRank-Task)) can be created as follows
```
  my $task = LibRank::Task->new(sid => <task id>, query => <query>);
  foreach my $doc (@docs) {
    $task->add_doc($doc);
  }
```
A document looks like this
```
{
  record_id => <record id>,
  features  => { <feature key> => <feature value>, ... },
  qrel      => {
    gradual => <gradual relevance judgment>,
    binary  => <binary relevance judgment>
  }
}
```

There is no actual default configuration for the `tasks` service, but 
an example that uses the `LibRank::Task::JSONReader` to read data from
a file. The `JSONReader` reads in flattened tasks. I.e. it expects 
one document per line added with data for the task (`SearchTask`, 
`query`) it belongs to. The documents must be sorted by `SearchTask`.

### Running

Start the API as usual, e.g.

```
starman -Ilib --preload-app librank_demonstrator_api.psgi
```
The app should be preloaded so that especially task data/feature matrices are shared between workers.

Then make the API accessible under `/api` within the same domain as the UI.

