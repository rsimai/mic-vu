#include <fcntl.h>
#include <math.h>
#include <pulse/error.h>
#include <pulse/simple.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

static volatile sig_atomic_t g_running = 1;

static void handle_sigterm(int sig) {
    (void)sig;
    g_running = 0;
}

static void state_paths(char *state_path, size_t state_len, char *pid_path, size_t pid_len) {
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    if (!runtime || runtime[0] == '\0') {
        runtime = "/tmp";
    }
    uid_t uid = getuid();
    snprintf(state_path, state_len, "%s/micvu-level-%u", runtime, (unsigned)uid);
    snprintf(pid_path, pid_len, "%s/micvu-daemon-%u.pid", runtime, (unsigned)uid);
}

static int write_level(const char *state_path, double level) {
    FILE *f = fopen(state_path, "w");
    if (!f) {
        return 1;
    }
    fprintf(f, "%.6f\n", level);
    fclose(f);
    return 0;
}

static int read_level(const char *state_path) {
    FILE *f = fopen(state_path, "r");
    if (!f) {
        printf("0.000000\n");
        return 0;
    }

    double level = 0.0;
    if (fscanf(f, "%lf", &level) != 1) {
        level = 0.0;
    }
    fclose(f);

    if (level < 0.0) {
        level = 0.0;
    }
    if (level > 1.0) {
        level = 1.0;
    }

    printf("%.6f\n", level);
    return 0;
}

static int pid_running(const char *pid_path) {
    FILE *f = fopen(pid_path, "r");
    if (!f) {
        return 0;
    }

    long pid = 0;
    int ok = fscanf(f, "%ld", &pid) == 1;
    fclose(f);
    if (!ok || pid <= 1) {
        return 0;
    }

    return kill((pid_t)pid, 0) == 0;
}

static int write_pid(const char *pid_path) {
    FILE *f = fopen(pid_path, "w");
    if (!f) {
        return 1;
    }
    fprintf(f, "%ld\n", (long)getpid());
    fclose(f);
    return 0;
}

static int run_daemon(const char *state_path, const char *pid_path) {
    static const int sample_rate = 16000;
    static const int channels = 1;
    static const int samples = 320;

    int16_t buffer[samples];
    int error = 0;

    pa_sample_spec ss;
    ss.format = PA_SAMPLE_S16LE;
    ss.rate = sample_rate;
    ss.channels = channels;

    pa_simple *stream = pa_simple_new(
        NULL,
        "mic-vu",
        PA_STREAM_RECORD,
        NULL,
        "mic-level",
        &ss,
        NULL,
        NULL,
        &error
    );

    if (!stream) {
        fprintf(stderr, "Pulse init failed: %s\n", pa_strerror(error));
        return 1;
    }

    if (write_pid(pid_path) != 0) {
        pa_simple_free(stream);
        return 1;
    }

    signal(SIGTERM, handle_sigterm);
    signal(SIGINT, handle_sigterm);

    while (g_running) {
        if (pa_simple_read(stream, buffer, sizeof(buffer), &error) < 0) {
            fprintf(stderr, "Pulse read failed: %s\n", pa_strerror(error));
            break;
        }

        double sum_sq = 0.0;
        for (int i = 0; i < samples; ++i) {
            double v = (double)buffer[i] / 32768.0;
            sum_sq += v * v;
        }

        double rms = sqrt(sum_sq / (double)samples);
        if (rms < 0.0) {
            rms = 0.0;
        }
        if (rms > 1.0) {
            rms = 1.0;
        }

        if (write_level(state_path, rms) != 0) {
            break;
        }
    }

    pa_simple_free(stream);
    unlink(pid_path);
    return 0;
}

static int start_daemon(const char *self_path, const char *pid_path) {
    if (pid_running(pid_path)) {
        return 0;
    }

    pid_t pid = fork();
    if (pid < 0) {
        return 1;
    }
    if (pid > 0) {
        return 0;
    }

    if (setsid() < 0) {
        _exit(1);
    }

    int devnull = open("/dev/null", O_RDWR);
    if (devnull >= 0) {
        dup2(devnull, STDIN_FILENO);
        dup2(devnull, STDOUT_FILENO);
        dup2(devnull, STDERR_FILENO);
        if (devnull > STDERR_FILENO) {
            close(devnull);
        }
    }

    execl(self_path, self_path, "--daemon", NULL);
    _exit(1);
}

int main(int argc, char **argv) {
    char state_path[256];
    char pid_path[256];
    state_paths(state_path, sizeof(state_path), pid_path, sizeof(pid_path));

    if (argc >= 2 && strcmp(argv[1], "--start") == 0) {
        return start_daemon(argv[0], pid_path);
    }
    if (argc >= 2 && strcmp(argv[1], "--read") == 0) {
        return read_level(state_path);
    }
    if (argc >= 2 && strcmp(argv[1], "--daemon") == 0) {
        return run_daemon(state_path, pid_path);
    }
    if (argc >= 2 && strcmp(argv[1], "--stop") == 0) {
        FILE *f = fopen(pid_path, "r");
        if (f) {
            long pid = 0;
            if (fscanf(f, "%ld", &pid) == 1 && pid > 1) {
                kill((pid_t)pid, SIGTERM);
            }
            fclose(f);
        }
        return 0;
    }

    fprintf(stderr, "usage: %s [--start|--read|--daemon|--stop]\n", argv[0]);
    return 1;
}
