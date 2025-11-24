class Dict(dict):
    def __getattribute__(self, name):
        if not hasattr(dict, name):
            return self.get(name)
        return super().__getattribute__(name)
