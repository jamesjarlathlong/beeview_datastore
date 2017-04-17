'''
Simple Flask application to test deployment to Amazon Web Services
Uses Elastic Beanstalk and RDS

Author: Scott Rodkey - rodkeyscott@gmail.com

Step-by-step tutorial: https://medium.com/@rodkey/deploying-a-flask-application-on-aws-a72daba6bb80
'''

from flask import (Flask, render_template, request, Response, make_response, jsonify)
from application import db
from application.models import accel_data, experiment_meta
from application.forms import RetrieveDBInfo
import config
import json
import collections
import io
import csv
from sqlalchemy import func
import itertools
# Elastic Beanstalk initalization
application = Flask(__name__)
application.debug=True
# change this to your own value
application.secret_key = config.SECRET_KEY

@application.route('/', methods=['GET'])
def index():
    return make_response(open('templates/index.html').read())

@application.route('/experiments', methods = ['GET'])
def experiments():
    all_experiments = [extract_meta(i) for i in experiment_meta.query.all()]
    print(all_experiments)
    return Response(json.dumps(all_experiments), status = 200)

def extract_meta(row):
    range_in_secs = int((row.max_sequence_id-row.min_sequence_id)/1000)
    return {'name': row.folder_name, 'range':range_in_secs ,
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
@application.route('/large.csv', methods = ['POST'])
def generate_large_csv():
    #start_seq = request.form.min_sequence
    #end_seq = request.form.max_sequence
    jsonified = func.array_to_json(func.array_agg(func.row(accel_data.seq_id, accel_data.node, accel_data.axis, accel_data.accel)))
    node_range = [5, 6, 7, 15, 17, 18, 20, 21, 22, 23, 24, 25, 27, 29, 30, 31, 32, 33, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 49, 52, 53, 54, 55, 56, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69]
    translation = {'f1':'seq_id', 'f2':'node', 'f3':'axis','f4':'accel'}
    vectors = (db.session.query(accel_data.seq_id, jsonified)
             .group_by(accel_data.seq_id)
             .order_by(accel_data.seq_id)
             .filter(accel_data.seq_id.between(30124655140, 30124665140))
             )
    just_arrays = (just_data(i) for i in vectors)
    translated = (arraydict_translator(translation, arr) for arr in just_arrays)
    tstamped_arrs = (merge_timestep(onet) for onet in translated)
    headers = ["seq_id"]+[stringify(i) for i in itertools.product(node_range, ['x','y','z'])]
    header_dict = collections.OrderedDict()
    for k in headers:
        header_dict[k] = None
    def data():
        csvfile = io.StringIO()
        headerwriter = csv.DictWriter(csvfile, delimiter=',', fieldnames = header_dict)
        headerwriter.writeheader()
        yield csvfile.getvalue()
        for i in tstamped_arrs:
            test_dixt = collections.OrderedDict({k:i.get(k,None) for k in header_dict})
            csvfile = io.StringIO()
            csvwriter = csv.DictWriter(csvfile, delimiter=',', fieldnames = header_dict)
            csvwriter.writerow(test_dixt)
            val = csvfile.getvalue()
            yield val
    response = Response(data(), mimetype='text/csv')
    response.headers["Content-Disposition"] = "attachment; filename=test.csv"
    return response
@application.route('/index', methods=['GET', 'POST'])
def inex():
    form1 = EnterDBInfo(request.form) 
    form2 = RetrieveDBInfo(request.form) 
    
    if request.method == 'POST' and form1.validate():
        data_entered = Data(notes=form1.dbNotes.data)
        try:     
            db.session.add(data_entered)
            db.session.commit()        
            db.session.close()
        except:
            db.session.rollback()
        return render_template('thanks.html', notes=form1.dbNotes.data)
        
    if request.method == 'POST' and form2.validate():
        try:   
            num_return = int(form2.numRetrieve.data)
            query_db = Data.query.order_by(Data.id.desc()).limit(num_return)
            for q in query_db:
                print(q.notes)
            db.session.close()
        except:
            db.session.rollback()
        return render_template('results.html', results=query_db, num_return=num_return)                
    
    return render_template('index.html', form1=form1, form2=form2)

if __name__ == '__main__':
    application.run(host='0.0.0.0')
