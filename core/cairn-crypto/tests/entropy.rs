// ADR 0024: aws-lc seeds from the OS CSPRNG; its CPU jitter source aborts the process on failure.
#[cfg(feature = "aws-lc")]
#[test]
fn aws_lc_seeds_without_cpu_jitter_entropy() {
    assert!(aws_lc_rs::try_fips_cpu_jitter_entropy().is_err());
}
