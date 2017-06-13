import psycopg2
import functools
import config
from helper import with_connection, compose, pipe
psycopg_conn = functools.partial(with_connection, psycopg2, config.SQLALCHEMY_DATABASE_URI)

@psycopg_conn
def files(cnn, exp_name):
    cur = cnn.cursor()
    cur.execute("select * from file_meta where folder_name = %s;", (exp_name,))
    return cur.fetchall()
def file_bookends(files):
	return sorted([(i[2], i[3]) for i in files], key = lambda x: x[0])

@psycopg_conn
def get_min_max(cnn,exp_name):
    cur = cnn.cursor()
    cur.execute("""select min_sequence_id, max_sequence_id from experiment_meta
                where folder_name = %s""", (exp_name,))
    return cur.fetchone()
    
@psycopg_conn
def get_first_full(cnn,min_sequence_id, max_sequence_id):
    cur = cnn.cursor()
    query = """SELECT seq_id, COUNT(*) as counter FROM accel_data
             WHERE seq_id BETWEEN %s AND %s
             GROUP BY seq_id;
            """
    cur.execute(query, (min_sequence_id, max_sequence_id))
    all_present = (i for i in cur if i[1]==144)
    return min(all_present)
@psycopg_conn
def update_full(cnn, folder_n, seq_id):
	cur = cnn.cursor()
	query = """INSERT into experiment_meta (folder_name, min_sequence_id)
               VALUES (%(folder)s, %(mini)s) ON CONFLICT (folder_name)
               DO UPDATE SET (min_sequence_id) = (%(mini)s);"""
	cur.execute(query, {'folder':folder_n, 'mini':seq_id})

if __name__ == "__main__":
	folder_n = 'ambient_1hr'
	get_folder_bookends = pipe(functools.partial(files, folder_n), file_bookends)
	first_bookend = get_folder_bookends()[0]
	first_full = get_first_full(*first_bookend)
	update_full(folder_n, first_full[0])