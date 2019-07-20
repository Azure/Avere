#!/bin/bash

mkdir rqd
virtualenv rqd
source rqd/bin/activate
pip install -r requirements.txt
python setup.py install
