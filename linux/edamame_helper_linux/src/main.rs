//#[cfg(linux)]
fn main() {
    edamame_helper::run();
}

/*#[cfg(not(linux))]
fn main() {
    panic!("This program is only intended to run on Linux.");
}*/

//#[cfg(linux)]
mod edamame_helper {
    use edamame_helper::{start_server, stop_server};

    pub fn run() {
        start_server();    
    }
}
