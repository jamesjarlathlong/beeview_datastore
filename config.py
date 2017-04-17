# edit the URI below to add your RDS password and your AWS URL
# The other elements are the same as used in the tutorial
# format: (user):(password)@(db_identifier).amazonaws.com:3306/(db_name)
import os
rds_pw = os.environ.get('AWS_RDS_PW')
SECRET_KEY = os.environ.get('BEEVIEW_SECRET')

SQLALCHEMY_DATABASE_URI = ("postgresql://lisslabmit:{password}"
                          "@beeview.civ5nnslgl2h.us-east-1.rds.amazonaws.com:5432/STW").format(password=rds_pw)
# Uncomment the line below if you want to work with a local DB
#SQLALCHEMY_DATABASE_URI =  ("postgresql://postgres:{password}"
#                          "@127.0.0.1:5432/stw").format(password='beeview')
SQLALCHEMY_POOL_RECYCLE = 3600
WTF_CSRF_ENABLED = True
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET')

