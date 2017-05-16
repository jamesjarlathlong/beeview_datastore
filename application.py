'''
Simple Flask application to test deployment to Amazon Web Services
Uses Elastic Beanstalk and RDS

Author: Scott Rodkey - rodkeyscott@gmail.com

Step-by-step tutorial: https://medium.com/@rodkey/deploying-a-flask-application-on-aws-a72daba6bb80
'''

from flask import (Flask, render_template, request, Response, make_response, jsonify)
from application import db
from application.models import accel_data, experiment_meta, file_meta
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
# change this to your own value

def with_connection(mod, db_filename, f):
    def with_connection_(*args, **kwargs):
        # or use a pool, or a factory function...
        cnn = mod.connect(db_filename)
        try:
            rv = f(cnn, *args, **kwargs)
        except Exception as e:
            cnn.rollback()
            raise
        else:
            cnn.commit() # or maybe not
        finally:
            cnn.close()
        return rv
    return with_connection_
psycopg_connector = functools.partial(with_connection, psycopg2, config.SQLALCHEMY_DATABASE_URI)
@application.route('/', methods=['GET'])
def index():
    return make_response(open('templates/index.html').read())

@application.route('/experiments', methods = ['GET'])
def experiments():
    all_experiments = [extract_meta(i) for i in experiment_meta.query.all()]
    #all_experiments = [{'name':'experiment1','excitation':'longambientfake','range':10000000,'damage':'undamagedfake','minseq':2,'maxseq':120000000}]
    return Response(json.dumps(all_experiments), status = 200)

def extract_meta(row):
    return {'name': row.folder_name,
            'damage': row.damage, 'excitation': row.excitation,
            'minseq':row.min_sequence_id, 'maxseq':row.max_sequence_id}
def just_data(row):
    return row[1]
def dict_translator(translation, d):
    return {translation[k]:v for k, v in d.items()}
def arraydict_translator(translation, arr):
    return [merge_sensor(dict_translator(translation, d)) for d in arr]
def merge_sensor(d):
    strified = stringify((d['node'],d['axis']))
    d[strified] = int_to_g(d['accel'])
    return {k:v for k,v in d.items()}
def merge_timestep(array_of_dicts):
    return dict(collections.ChainMap(*array_of_dicts))
def stringify(tpl):
    return str(tpl[0])+str(tpl[1])
def int_to_g(accel):
    vref = 2.4
    max_val = (2**16)/2 -1
    num_to_volt = vref/max_val
    volt_to_g = 5/3.3
    num_to_g = num_to_volt*accel*volt_to_g
    return num_to_g
def possible_nodes():
    return [5, 6, 7, 15, 17, 18, 20, 21, 22, 23, 24, 25, 27, 29, 30, 31, 32, 33, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 49, 52, 53, 54, 55, 56, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69]    
def num_sensors():
    return len(list(itertools.product(possible_nodes(), ['x','y','z'])))

@application.route('/large.csv', methods = ['POST'])
def generate_large_csv():
    #start_seq = request.form.min_sequence
    #end_seq = request.form.max_sequence
    print('req: ', dict(request.form))
    specs = {k:v for k,v in request.form.items()}
    print("specs: ", specs)
    query = form_query(specs)
    arrs = get_arrs(query)
    noderange = possible_nodes()
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
def get_arrs(query):
    translation = {'f1':'seq_id', 'f2':'node', 'f3':'axis','f4':'accel'}
    just_arrays = (just_data(i) for i in query)
    translated = (arraydict_translator(translation, arr) for arr in just_arrays)
    tstamped_arrs = (merge_timestep(onet) for onet in translated)
    return tstamped_arrs
def get_file_writer(arrs, noderange):
    headers = ["seq_id"]+[stringify(i) for i in itertools.product(noderange, ['x','y','z'])]
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
