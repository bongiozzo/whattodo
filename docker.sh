docker build -t antora-debian .
docker run -v $PWD:/antora:Z --rm -it antora-debian bash
