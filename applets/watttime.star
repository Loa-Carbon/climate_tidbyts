load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("hash.star", "hash")

# base wattime api url
BASE_URL = "https://api2.watttime.org/v2"  

# cache token for 29 minutes
TOKEN_EXPIRATION_SECONDS = 1740  

# 5 minutes index cache for each balancing authority
INDEX_CACHE_EXPIRATION_SECONDS = 300


def main(config):
    username = config.get("username")
    password = config.get("password")
    balancing_authority = config.get("ba")

    if username == None or password == None or balancing_authority == None:
        return render_message("Configure Watttime Settings")

    else:
        token = get_token(username, password)
        if token == None:
            return render_message("Check Watttime Login Credentials")
        else:
            return render_index(token, balancing_authority)


def render_message(message):
    return render.Root(
        render.Row(
            expanded=True,
            main_align="center",
            cross_align="center",
            children=[
                render.Column(
                    expanded=True,
                    main_align="center",
                    cross_align="center",
                    children=[
                        render.WrappedText(message,
                                           font="tom-thumb",
                                           color="#fa0")
                    ]
                )
            ]
        )
    )


def get_token(username, password):
    token_cache_key = "watttime-token-%s-%s" % (username, hash.md5(password))
    token = cache.get(token_cache_key)

    if token == None:
        print("Token cache miss, calling api to get token")
        response = http.get("%s/login" % BASE_URL, auth=(username, password))
        if response.status_code != 200:
            print("Request failed with status %d" % response.status_code)
            return None
        else:
            token = response.json().get("token", None)
            cache.set(token_cache_key, token,
                      ttl_seconds=TOKEN_EXPIRATION_SECONDS)
            return token
    else:
        print("Token cache hit")
        return token


def render_index(token, balancing_authority):
    index = get_index(token, balancing_authority)

    if index == None:
        return render_message("Could not retrieve index for %s" % balancing_authority)

    else:
        index_color = get_index_color(index)

        return render.Root(
            render.Row(
                expanded=True,
                main_align="center",
                cross_align="center",
                children=[
                    render.Column(
                        expanded=True,
                        main_align="center",
                        cross_align="center",
                        children=[
                            render.WrappedText("watttime index",
                                               font="tom-thumb"),
                            render.WrappedText("%s: %s" % (balancing_authority, index),
                                               font="tom-thumb",
                                               color=index_color)
                        ]
                    )
                ]
            )
        )


def get_index(token, balancing_authority):
    index_cache_key = "watttime-index-%s" % balancing_authority
    index = cache.get(index_cache_key)

    if index == None:
        print("Index cache miss, calling api to get index for %s" %
              balancing_authority)
        headers = {"Authorization": "Bearer %s" % token}
        params = {"ba": balancing_authority}
        response = http.get("%s/index" %
                            BASE_URL, params=params, headers=headers)
        if response.status_code != 200:
            print("Index request failed with status %d" % response.status_code)
            return None
        else:
            json = response.json()
            index = json.get("percent", "?")
            cache.set(index_cache_key, index,
                      ttl_seconds=INDEX_CACHE_EXPIRATION_SECONDS)
            return index
    else:
        print("Index cache hit")
        return index


def get_index_color(index):
    index_int = int(index)

    if index_int < 26:
        return "#0f0"  # green
    elif index_int < 51:
        return "#ff0"  # yellow
    elif index_int < 76:
        return "#ffa500"  # orange

    return "#f00"  # red
