# Using Docker

Note that this is currently configured for ease of development.  The primary
consequences of this are:
- The DB running in a container is not well secured.
  - To correct this, make proper use of `.env` files not in `git.
- The application files are mounted from the file system rather than contained in the app container.
  - To correct this, use `COPY` within the `Dockerfile` instead of the mountings in `volumes` in the `docker-compose` file.



## Containers

### montclairptac-db0

This runs a Mysql database.  It provides persistence for the app
container.

### montclairptac-app

This is a no-op container from Docker's perspective: it starts and
does nothing.  It is intended for use by people via:

```
  docker exec -it montclairptac-app bash
```

From that internal shell, one can run the various commands
provided by this software to deal with the student data
provided by the district.

## Storage

### Application Files

The docker-compose file currently mounts `app/{bin,db,tmp}` from the local
file system rather than letting these be used from within the container.
This means that one can edit scripts in `app/bin` from outside the container
(with one's usual editor) and then run them within the container (thereby
using the libraries, utilities, etc. in the container plus the MySQL container's
data server) for testing.  This is a non-standard way to use Docker, but
it speed the development cycle.

### Database

The database persists in a docker volume.  It can be removed (thereby requiring
that it be rebuilt) with:

```
docker container rm montclairptac-db0
docker volume rm 0_montclairptac-dbdata0
```

Note that this requires that the container be removed to free up
the volume for removal.

At the moment, rebuilding the DB volume does not restore the schema.
That is a separate process (and one under development as of this
writing).

## Starting

The quick way to build and start the containers:
```
docker compose --profile app --ansi never down && docker compose --profile app --ansi never up --build
```

Note that this runs the containers in the foreground.  If one wants to
run them in detached mode, add `-d` after `up`.

To run a shell within the app container, gaining access to the various
utilities, run:

```
docker exec -it montclairptac-app bash
```

To run `mysql` within the container's shell:
```
mysql --user=${MYSQL_USER} --password=${MYSQL_PASSWORD} ${MYSQL_DATABASE}
```
