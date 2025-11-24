from os.path import join

from .methods import _create_directory, _get_location_data, _upload_files
from .utils import norm_location, slugify, to_uint
from .search import search_generator


class MediaManager:
    media_dir: str
    limit_results: int

    def __init__(self, media_dir: str, limit_results: int = 20):
        self.media_dir = media_dir.rstrip("/")
        self.limit_results = limit_results

    def _norm_location(self, location: str):
        return join(self.media_dir, norm_location(location).lstrip("/"))

    def get_location_data(self, location: str, skip: int = 0):
        location = self._norm_location(location)
        skip = to_uint(skip)
        limit = self.limit_results
        return _get_location_data(self.media_dir, location, skip, limit)

    def create_directory(self, location: str, name: str):
        location = self._norm_location(location)
        name = slugify(name)
        return _create_directory(self.media_dir, location, name)

    def upload_files(
        self,
        location: str,
        files: list,
        upload_in_current_dir: bool,
    ):
        media_dir = self.media_dir
        thumb_dir = join(media_dir, "_thumb")
        rellocation = norm_location(location).lstrip("/")

        return _upload_files(
            media_dir, thumb_dir, rellocation, files, upload_in_current_dir
        )

    def get_search_data(self, location: str, q: str):
        abslocation = self._norm_location(location)

        return search_generator(abslocation, q, self.media_dir)
