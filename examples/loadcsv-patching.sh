#! /bin/bash

puppet plan run node_info::load_csv --params @node_info::load_csv-patching.json

