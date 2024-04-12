package main

import (
	"archive/tar"
	"compress/gzip"
	"crypto/md5"
	"errors"
	"fmt"
	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"
)

const upstreamUrl = "https://github.com/discourse/discourse_docker"

type CliUpgrade struct {
	Version string `default:"latest" name:"target-version" short:"v" help:"upgrade to a specific version of launcher"`
}

func (r *CliUpgrade) Run(cli *Cli) error {
	fmt.Fprintln(utils.Out, "Upgrading to "+r.Version+"...")
	ex, err := os.Executable()
	if err != nil {
		return err
	}
	ex, err = filepath.EvalSymlinks(ex)
	exDir := path.Dir(ex)

	if err != nil {
		return err
	}

	baseUrl := upstreamUrl + "/releases/download/" + r.Version + "/"
	bundle := "launcher2-" + r.Version + "-" + runtime.GOOS + "-" + runtime.GOARCH + ".tar.gz"
	bundleHash := bundle + ".md5"
	downloadDir, _ := os.MkdirTemp("", "launcher2")
	bundleFilename := downloadDir + "/" + bundle
	bundleHashFilename := downloadDir + "/" + bundleHash
	defer os.RemoveAll(downloadDir)

	err = downloadFile(baseUrl+bundle, bundleFilename)
	if err != nil {
		return err
	}
	err = downloadFile(baseUrl+bundleHash, bundleHashFilename)
	if err != nil {
		return err
	}

	err = checksumFile(bundleFilename, bundleHashFilename)
	if err != nil {
		return err
	}

	err = ExtractTarGz(bundleFilename, exDir)
	if err != nil {
		return err
	}

	fmt.Fprintln(utils.Out, "launcher updated")
	return nil
}

func downloadFile(fileUrl string, filename string) error {
	client := http.Client{}
	resp, err := client.Get(fileUrl)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if 400 <= resp.StatusCode && resp.StatusCode < 600 {
		return errors.New(fileUrl + " responded with an error: " + resp.Status)
	}
	file, err := os.Create(filename)
	_, err = io.Copy(file, resp.Body)
	if err != nil {
		return err
	}
	defer file.Close()
	return nil
}

func checksumFile(filename string, checksumFilename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()
	checksumOut, err := os.ReadFile(checksumFilename)
	if err != nil {
		return err
	}
	checksumOutStr := strings.TrimSpace(string(checksumOut[:]))

	hash := md5.New()
	_, err = io.Copy(hash, file)
	if err != nil {
		return err
	}
	checksum := fmt.Sprintf("%x", hash.Sum(nil))

	if strings.Compare(checksum, checksumOutStr) != 0 {
		return errors.New("Checksum failed")
	}
	return nil
}

func ExtractTarGz(filename string, targetDirectory string) error {
	gzipStream, err := os.Open(filename)
	if err != nil {
		return err
	}
	uncompressedStream, err := gzip.NewReader(gzipStream)
	if err != nil {
		return err
	}

	tarReader := tar.NewReader(uncompressedStream)
	var header *tar.Header
	for header, err = tarReader.Next(); err == nil; header, err = tarReader.Next() {
		switch header.Typeflag {
		case tar.TypeDir:
			if err := os.Mkdir(targetDirectory+"/"+header.Name, 0755); err != nil {
				return fmt.Errorf("ExtractTarGz: Mkdir() failed: %w", err)
			}
		case tar.TypeReg:
			outFile, err := os.Create(targetDirectory + "/" + header.Name)
			if err != nil {
				return fmt.Errorf("ExtractTarGz: Create() failed: %w", err)
			}

			if _, err := io.Copy(outFile, tarReader); err != nil {
				// outFile.Close error omitted as Copy error is more interesting at this point
				outFile.Close()
				return fmt.Errorf("ExtractTarGz: Copy() failed: %w", err)
			}
			if err := outFile.Close(); err != nil {
				return fmt.Errorf("ExtractTarGz: Close() failed: %w", err)
			}
		default:
			return fmt.Errorf("ExtractTarGz: uknown type: %b in %s", header.Typeflag, header.Name)
		}
	}
	if err != io.EOF {
		return fmt.Errorf("ExtractTarGz: Next() failed: %w", err)
	}
	return nil
}

func CheckVersion() error {
	client := http.Client{}
	versionUrl := upstreamUrl + "/releases/download/latest/launcher_version.txt"
	resp, err := client.Get(versionUrl)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if 400 <= resp.StatusCode && resp.StatusCode < 600 {
		return errors.New(versionUrl + " responded with an error: " + resp.Status)
	}
	bodyRaw, err := io.ReadAll(resp.Body)
	newVersion := strings.TrimSpace(string(bodyRaw[:]))
	if err != nil {
		return err
	}
	if strings.Compare(utils.Version, newVersion) != 0 {
		fmt.Fprintln(utils.Out, "New launcher version available.\n",
			"current version:", utils.Version, "\n",
			"new version:", newVersion)
	}
	return nil
}
