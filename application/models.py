from application import db
from sqlalchemy.dialects import postgresql
class accel_data(db.Model):
    node = db.Column(db.Integer, primary_key=True)
    axis = db.Column(db.String, primary_key=True)
    seq_id = db.Column(db.BigInteger, primary_key=True)
    time_stamp = db.Column(db.BigInteger,unique=False)
    accel = db.Column(db.Integer, unique=False)

class file_meta(db.Model):
    file_name = db.Column(db.String, primary_key=True)
    folder_name = db.Column(db.String, unique=False)
    min_sequence_id = db.Column(db.BigInteger, unique=False)
    max_sequence_id = db.Column(db.BigInteger, unique=False)

class experiment_meta(db.Model):
    folder_name = db.Column(db.String, primary_key=True)
    min_sequence_id = db.Column(db.BigInteger, unique=False)
    max_sequence_id = db.Column(db.BigInteger, unique=False)
    excitation = db.Column(db.String, unique=False)
    damage = db.Column(db.String, unique=False)
    date = db.Column(db.String, unique=False)


    