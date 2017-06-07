'''
Simple Flask application to test deployment to Amazon Web Services
Uses Elastic Beanstalk and RDS

Author: Scott Rodkey - rodkeyscott@gmail.com

Step-by-step tutorial: https://medium.com/@rodkey/deploying-a-flask-application-on-aws-a72daba6bb80
'''

from flask import (Flask, render_template, request, Response, make_response, jsonify)
from application import db
from application.models import accel_data, experiment_meta, file_meta
import application.query_helpers as helpers
import config
import json
import collections
import io
import csv
from sqlalchemy import func
import itertools
import functools
import psycopg2
# Elastic Beanstalk initalization

from application import application

@application.route('/', methods=['GET'])
def index():
    return make_response(open('templates/index.html').read())

@application.route('/experiments', methods = ['GET'])
def experiments():
    all_experiments = [helpers.extract_meta(i) for i in experiment_meta.query.all()]
    #all_experiments = [{'name':'experiment1','excitation':'longambientfake','range':10000000,'damage':'undamagedfake','minseq':2,'maxseq':120000000}]
    return Response(json.dumps(all_experiments), status = 200)



@application.route('/large.csv', methods = ['POST'])
def generate_large_csv():
    #start_seq = request.form.min_sequence
    #end_seq = request.form.max_sequence
    print('req: ', dict(request.form))
    specs = {k:v for k,v in request.form.items()}
    print("specs: ", specs)
    query = form_query(specs)
    print('got the arrs')
    arrs = helpers.get_arrs(query)
    noderange = helpers.possible_nodes()
    writer = get_file_writer(arrs, noderange)
    response = Response(writer(), mimetype='text/csv')
    #response = Response(status = 200)
    response.headers["Content-Disposition"] = "attachment; filename=test.csv"
    return response
def form_query(specs):
    jsonified = func.array_to_json(func.array_agg(func.row(accel_data.seq_id, accel_data.node, accel_data.axis, accel_data.accel)))
    starting_seq = int(specs['min_sequence'])
    ending_seq = min(int(specs['max_sequence']), starting_seq+1000*int(specs['user_length']))
    skip_every = int(1000/int(specs['freq']))
    print(starting_seq, ending_seq)
    vectors = (db.session.query(accel_data.seq_id, jsonified)
             .group_by(accel_data.seq_id)
             .order_by(accel_data.seq_id)
             .filter(accel_data.seq_id.between(starting_seq, ending_seq))
             .filter(accel_data.seq_id%skip_every == 0))
    return vectors

def get_file_writer(arrs, noderange):
    headers = ["seq_id"]+[helpers.stringify(i) for i in itertools.product(noderange, ['x','y','z'])]
    header_dict = collections.OrderedDict()
    for k in headers:
        header_dict[k] = None
    def data_writer(header_dictionary,arrays):
        csvfile = io.StringIO()
        headerwriter = csv.DictWriter(csvfile, delimiter=',', fieldnames = header_dictionary)
        headerwriter.writeheader()
        yield csvfile.getvalue()
        for i in arrays:
            test_dixt = collections.OrderedDict({k:i.get(k,None) for k in header_dictionary})
            csvfile = io.StringIO()
            csvwriter = csv.DictWriter(csvfile, delimiter=',', fieldnames = header_dictionary)
            csvwriter.writerow(test_dixt)
            val = csvfile.getvalue()
            yield val
    return functools.partial(data_writer, header_dict, arrs)
if __name__ == '__main__':
    application.run()
