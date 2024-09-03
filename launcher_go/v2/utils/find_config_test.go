package utils_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/discourse/discourse_docker/launcher_go/v2/utils"
	"os"
)

var _ = Describe("FindConfig", func() {

	It("Parses and returns yml or yaml files", func() {
		os.Setenv("COMP_LINE", "launcher2 build --conf-dir ../test/containers")
		Expect(utils.FindConfigNames()).To(ContainElements("test", "test2"))
	})

	It("Parses and returns yml or yaml files with trailing slash", func() {
		os.Setenv("COMP_LINE", "launcher2 build --conf-dir ../test/containers/")
		Expect(utils.FindConfigNames()).To(ContainElements("test", "test2"))
	})

	It("Parses and returns yml or yaml files on equals", func() {
		os.Setenv("COMP_LINE", "launcher2 --conf-dir=../test/containers other args")
		Expect(utils.FindConfigNames()).To(ContainElements("test", "test2"))
	})

	It("doesn't error when dir does not exist when set", func() {
		os.Setenv("COMP_LINE", "launcher2 --conf-dir=./does-not-exist")
		Expect(utils.FindConfigNames()).To(BeEmpty())
	})

	It("doesn't error when dir does not exist", func() {
		//by default it look is in ./containers directory, which does not exist
		// in this directory
		os.Setenv("COMP_LINE", "launcher2")
		Expect(utils.FindConfigNames()).To(BeEmpty())
	})
})
