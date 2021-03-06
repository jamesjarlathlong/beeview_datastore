'''
Simple Flask application to test deployment to Amazon Web Services
Uses Elastic Beanstalk and RDS

Author: Scott Rodkey - rodkeyscott@gmail.com

Step-by-step tutorial: https://medium.com/@rodkey/deploying-a-flask-application-on-aws-a72daba6bb80
'''

from flask import (Flask, render_template, request, Response, make_response, jsonify, stream_with_context)
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
import helper as func_helper
# Elastic Beanstalk initalization

from application import application

@application.route('/', methods=['GET'])
def index():
    return make_response(open('templates/index.html').read())

@application.route('/experiments', methods = ['GET'])
def experiments():
    white_list=['BL_pink_04', 'D3_pink_01', 'BL_pink_05', 'intact_whitenoise_1', 'ambient_1hr', 'D3_pink_02', 'D4_pink_01', 'bolt_loose_white_noise_1', 'bolt_loose_white_noise_2', 'D4_pink_02', 'D5_pink_01', 'D5_pink_02', 'intact_whitenoise_2', 'bolt_loose_white_noise_3', 'D2_pink_01', 'D1_pink_01', 'three_elements_removed_white_noise_1', 'BL_pink_02', 'BL_pink_03']
    all_experiments = [helpers.extract_meta(i) for i in experiment_meta.query.all()]
    print('exp:',all_experiments)
    white_listed = [i for i in all_experiments if i['name'] in white_list]
    nicknamed = white_listed#[helpers.nickname(i) for i in white_listed]
    print(nicknamed)
    return Response(json.dumps(nicknamed), status = 200)

@application.route('/large.csv', methods = ['POST'])
def generate_large_csv():
    #start_seq = request.form.min_sequence
    #end_seq = request.form.max_sequence
    print('req: ', dict(request.form))
    specs = {k:v for k,v in request.form.items()}
    print("specs: ", specs)
    query = form_query(specs)
    print('formed the query')
    arrs = helpers.get_arrs(query)
    print('got the arrs')
    noderange = range(1,49)#helpers.possible_nodes()
    writer = get_file_writer(arrs, noderange)
    response = Response(stream_with_context(writer()), mimetype='text/csv')
    #response = Response(status = 200)
    response.headers["Content-Disposition"] = "attachment; filename={}_{}Hz.csv".format(specs['folder_name'], specs['freq'])
    return response
def form_query(specs):
    jsonified = func.array_to_json(func.array_agg(func.row(accel_data.seq_id, accel_data.node, accel_data.axis, accel_data.accel)))
    starting_seq = int(specs['min_sequence']) + 2000*int(specs['userstart'])
    ending_seq = int(specs['min_sequence']) + 2000*int(specs['userfinish'])
    skip_every = int(2000/int(specs['freq']))
    print(starting_seq, ending_seq)
    vectors = (db.session.query(accel_data.seq_id, jsonified)
             .group_by(accel_data.seq_id)
             .order_by(accel_data.seq_id)
             .filter(accel_data.seq_id.between(starting_seq, ending_seq))
             .filter(accel_data.seq_id%skip_every == 0)).yield_per(1000)
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
    application.run(port=5000)
