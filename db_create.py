from application import db
from application.models import accel_data, file_meta, experiment_meta
db.drop_all()
db.create_all()

print("DB created.")
