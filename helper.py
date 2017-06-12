import functools
import itertools

def ld_to_dl(list_of_dicts):
    return dict(zip(list_of_dicts[0],zip(*[d.values() for d in list_of_dicts])))
def lazy_flattener(iterofiters):
    return itertools.chain(*iterofiters)
def eager_flattener(iterofiters):
    return list(lazy_flattener(iterofiters))
def powerset(iterable, smallest, largest):
    "powerset([1,2,3]) --> () (1,) (2,) (3,) (1,2) (1,3) (2,3) (1,2,3)"
    s = list(iterable)
    return itertools.chain.from_iterable(itertools.combinations(s, r) for r in
                                         range(smallest, min(largest+1, len(s)+1)))
def compose_two(func1, func2):
     def composition(*args, **kwargs):
        return func1(func2(*args, **kwargs))
     return composition
def compose(*funcs):
    return functools.reduce(compose_two, funcs)
def pipe(*funcs):
    return functools.reduce(compose_two, reversed(funcs))
def uqify(values):
    return list(set(values))
def merge_two_dicts(x, y):
    """Given two dicts, merge them into a new dict as a shallow copy."""
    z = x.copy()
    z.update(y)
    return z
def infinite_sequence():
    while True:
        yield 0
def infinite_range():
    i = 0
    while True:
        yield i
        i+=1