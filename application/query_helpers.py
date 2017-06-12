import collections
def withstreamingconn(engine, f):
    def with_connection_(*args, **kwargs):
        # or use a pool, or a factory function...
        with engine.connect() as cnn:
            result = f(cnn, *args, **kwargs)
            return result
    return with_connection_
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
def get_arrs(query):
    translation = {'f1':'seq_id', 'f2':'node', 'f3':'axis','f4':'accel'}
    just_arrays = (just_data(i) for i in query)
    translated = (arraydict_translator(translation, arr) for arr in just_arrays)
    tstamped_arrs = (merge_timestep(onet) for onet in translated)
    return tstamped_arrs